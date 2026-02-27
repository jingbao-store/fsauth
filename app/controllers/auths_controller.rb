class AuthsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:feishu_callback]

  # GET /auth/start?request_id=xxx&app_id=xxx
  # Entry point: Display authorization page
  def start
    @request_id = params[:request_id]
    @app_id = params[:app_id]
    
    unless @request_id.present?
      render plain: 'Missing request_id parameter', status: :bad_request
      return
    end

    unless @app_id.present?
      render plain: 'Missing app_id parameter', status: :bad_request
      return
    end
    
    @auth_request = AuthRequest.find_by(request_id: @request_id)
    
    unless @auth_request
      render plain: 'Invalid request_id', status: :not_found
      return
    end

    # Verify application exists and has credentials
    @application = Application.find_by(id: @app_id)
    unless @application&.credentials_configured?
      render plain: 'Invalid or unconfigured application', status: :bad_request
      return
    end

    # Link auth_request to application if not already linked
    if @auth_request.application_id != @application.id
      @auth_request.update(application_id: @application.id)
    end
    
    if @auth_request.expired?
      @auth_request.mark_as_expired!
      render :expired
      return
    end
    
    unless @auth_request.valid_request?
      render plain: 'Request already processed or invalid', status: :bad_request
      return
    end
  end

  # POST /auth/authorize?request_id=xxx&app_id=xxx
  # User confirms authorization, redirect to Feishu OAuth
  def authorize
    request_id = params[:request_id]
    app_id = params[:app_id]
    
    unless request_id.present?
      render plain: 'Missing request_id parameter', status: :bad_request
      return
    end

    unless app_id.present?
      render plain: 'Missing app_id parameter', status: :bad_request
      return
    end
    
    auth_request = AuthRequest.find_by(request_id: request_id)
    application = Application.find_by(id: app_id)
    
    unless auth_request&.valid_request?
      render plain: 'Invalid or expired request', status: :bad_request
      return
    end

    unless application&.credentials_configured?
      render plain: 'Invalid or unconfigured application', status: :bad_request
      return
    end
    
    # Generate state parameter for CSRF protection
    state = "#{request_id}:#{app_id}:#{SecureRandom.hex(16)}"
    session[:oauth_state] = state
    session[:request_id] = request_id
    session[:app_id] = app_id
    
    # Redirect to Feishu OAuth page with application credentials
    service = FeishuAuthService.new(
      app_id: application.feishu_app_id,
      app_secret: application.feishu_app_secret,
      redirect_uri: application.redirect_url(base_url: request.base_url)
    )
    redirect_to service.authorization_url(state: state), allow_other_host: true
  end

  # GET /auth/feishu/callback/:app_id
  # Feishu OAuth callback handler
  def feishu_callback
    code = params[:code]
    state = params[:state]
    app_id = params[:app_id]
    
    # Verify state parameter
    unless state == session[:oauth_state]
      render plain: 'Invalid state parameter - possible CSRF attack', status: :bad_request
      return
    end
    
    request_id = session[:request_id]
    stored_app_id = session[:app_id]

    unless app_id == stored_app_id
      render plain: 'App ID mismatch', status: :bad_request
      return
    end

    auth_request = AuthRequest.find_by(request_id: request_id)
    application = Application.find_by(id: app_id)
    
    unless auth_request&.valid_request?
      render plain: 'Invalid or expired request', status: :bad_request
      return
    end

    unless application&.credentials_configured?
      render plain: 'Invalid or unconfigured application', status: :bad_request
      return
    end
    
    begin
      # Exchange code for token using application credentials
      service = FeishuAuthService.new(
        app_id: application.feishu_app_id,
        app_secret: application.feishu_app_secret,
        redirect_uri: application.redirect_url(base_url: request.base_url)
      )
      token_data = service.exchange_code_for_token(code: code)
      
      # Get user info
      user_info = service.get_user_info(access_token: token_data['access_token'])
      
      # Store token and auth data
      auth_token = AuthToken.create!(
        application_id: application.id,
        request_id: request_id,
        token: token_data['access_token'],
        auth_data: {
          refresh_token: token_data['refresh_token'],
          expires_in: token_data['expires_in'],
          user_info: user_info
        }
      )
      
      # Mark request as authorized
      auth_request.mark_as_authorized!
      
      # Clear session
      session.delete(:oauth_state)
      session.delete(:request_id)
      session.delete(:app_id)
      
      # Show success page
      @request_id = request_id
      render :success
      
    rescue => e
      Rails.logger.error "Feishu OAuth error: #{e.message}"
      auth_request.mark_as_failed!
      render plain: "Authorization failed: #{e.message}", status: :internal_server_error
    end
  end

  private
  # Write your private methods here
end

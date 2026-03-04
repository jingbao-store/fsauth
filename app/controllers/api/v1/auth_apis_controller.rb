class Api::V1::AuthApisController < Api::BaseController
  # POST /api/v1/auth/request
  # Create a new auth request from openclaw
  # Params: app_id (required), scope (optional, array or string)
  def create_request
    app_id = params[:app_id]
    scope = params[:scope]

    unless app_id.present?
      render json: { error: 'app_id is required' }, status: :bad_request
      return
    end

    # Validate application exists and has credentials
    application = Application.find_by(id: app_id)
    unless application&.credentials_configured?
      render json: { error: 'Invalid or unconfigured application' }, status: :bad_request
      return
    end
    
    # Generate unique request_id
    request_id = SecureRandom.uuid
    
    # Create auth request (expires in 10 minutes)
    # Store scope if provided, ensure offline_access is always included
    # Accept both array and string formats:
    # - Array: ["bitable:app:readonly", "offline_access"]
    # - String: "bitable:app:readonly offline_access"
    scope_string = if scope.is_a?(Array)
                     scope.join(' ')
                   elsif scope.present?
                     scope.to_s
                   else
                     'offline_access'
                   end
    
    # Ensure offline_access is included
    unless scope_string.include?('offline_access')
      scope_string = "#{scope_string} offline_access".strip
    end
    
    auth_request = AuthRequest.create!(
      application_id: application.id,
      request_id: request_id,
      state: 'pending',
      scope: scope_string,
      expires_at: 10.minutes.from_now
    )
    
    # Generate authorization URL with app_id
    uri = URI.parse("#{request.base_url}/auth/start")
    uri.query = URI.encode_www_form(request_id: request_id, app_id: app_id)
    auth_url = uri.to_s
    
    render json: {
      request_id: request_id,
      auth_url: auth_url,
      expires_at: auth_request.expires_at.iso8601,
      message: 'Please open auth_url in browser to complete authorization'
    }, status: :created
  end

  # GET /api/v1/auth/token?request_id=xxx
  # Retrieve token after authorization completed
  def get_token
    request_id = params[:request_id]
    
    unless request_id.present?
      render json: { error: 'request_id is required' }, status: :bad_request
      return
    end
    
    auth_request = AuthRequest.find_by(request_id: request_id)
    
    unless auth_request
      render json: { error: 'Request not found' }, status: :not_found
      return
    end
    
    # Check if expired
    if auth_request.expired?
      auth_request.mark_as_expired! if auth_request.state == 'pending'
      render json: { 
        error: 'Request expired',
        state: 'expired',
        expired_at: auth_request.expires_at.iso8601
      }, status: :gone
      return
    end
    
    # Check state
    case auth_request.state
    when 'pending'
      render json: {
        state: 'pending',
        message: 'Authorization not completed yet'
      }, status: :accepted
      
    when 'failed'
      render json: {
        state: 'failed',
        error: 'Authorization failed'
      }, status: :unprocessable_entity
      
    when 'authorized'
      auth_token = AuthToken.find_by(request_id: request_id)
      
      unless auth_token
        render json: { error: 'Token not found' }, status: :not_found
        return
      end
      
      # Mark token as used
      auth_token.mark_as_used! unless auth_token.used?
      
      # Extract auth data
      user_info = auth_token.auth_data['user_info'] || {}
      
      # Calculate time remaining until expiration (in seconds)
      access_expires_in = if auth_token.access_token_expires_at
        [(auth_token.access_token_expires_at - Time.current).to_i, 0].max
      else
        auth_token.auth_data['expires_in'] # Use original value if no timestamp
      end
      
      refresh_expires_in = if auth_token.refresh_token_expires_at
        [(auth_token.refresh_token_expires_at - Time.current).to_i, 0].max
      else
        auth_token.auth_data['refresh_expires_in']
      end
      
      # Return standardized OAuth response format
      render json: {
        state: 'authorized',
        user_access_token: auth_token.token,
        refresh_token: auth_token.refresh_token,
        expires_in: access_expires_in,
        refresh_token_expires_in: refresh_expires_in,
        user_info: user_info,
        message: 'Authorization completed successfully'
      }, status: :ok
      
    else
      render json: {
        state: auth_request.state,
        error: 'Unknown state'
      }, status: :internal_server_error
    end
  end
  
  # GET /api/v1/auth/status?request_id=xxx
  # Check authorization status (for polling)
  def get_status
    request_id = params[:request_id]
    
    unless request_id.present?
      render json: { error: 'Missing request_id parameter' }, status: :bad_request
      return
    end
    
    auth_request = AuthRequest.find_by(request_id: request_id)
    
    unless auth_request
      render json: { error: 'Request not found' }, status: :not_found
      return
    end
    
    if auth_request.expired?
      auth_request.mark_as_expired! if auth_request.state == 'pending'
    end
    
    response_data = {
      request_id: request_id,
      state: auth_request.state,
      expired: auth_request.expired?
    }
    
    # If authorized, include token and user info
    if auth_request.state == 'authorized'
      auth_token = AuthToken.find_by(request_id: request_id)
      if auth_token
        user_info = auth_token.auth_data['user_info'] || {}
        
        # Calculate time remaining until expiration
        access_expires_in = if auth_token.access_token_expires_at
          [(auth_token.access_token_expires_at - Time.current).to_i, 0].max
        else
          auth_token.auth_data['expires_in']
        end
        
        refresh_expires_in = if auth_token.refresh_token_expires_at
          [(auth_token.refresh_token_expires_at - Time.current).to_i, 0].max
        else
          auth_token.auth_data['refresh_expires_in']
        end
        
        response_data.merge!({
          user_access_token: auth_token.token,
          refresh_token: auth_token.refresh_token,
          expires_in: access_expires_in,
          refresh_token_expires_in: refresh_expires_in,
          user_info: user_info
        })
      end
    end
    
    render json: response_data
  end

  # POST /api/v1/auth/refresh
  # Refresh user_access_token using refresh_token
  # Params: app_id (required)
  def refresh_token
    app_id = params[:app_id]
    
    unless app_id.present?
      render json: { error: 'app_id is required' }, status: :bad_request
      return
    end
    
    # Find application
    application = Application.find_by(id: app_id)
    unless application&.credentials_configured?
      render json: { error: 'Invalid or unconfigured application' }, status: :bad_request
      return
    end
    
    # Find auth token by application_id (one token per app)
    auth_token = AuthToken.find_by(application_id: application.id)
    unless auth_token
      render json: { 
        error: 'No token found for this application',
        message: 'Please authorize first via /api/v1/auth/request'
      }, status: :not_found
      return
    end
    
    # Check if refresh token is available
    unless auth_token.can_refresh?
      render json: { 
        error: 'Refresh token expired or unavailable',
        message: 'Please re-authorize via /api/v1/auth/request'
      }, status: :unauthorized
      return
    end
    
    begin
      # Initialize Feishu service with application credentials
      service = FeishuAuthService.new(
        app_id: application.feishu_app_id,
        app_secret: application.feishu_app_secret
      )
      
      # Refresh token
      new_token_data = service.refresh_user_access_token(refresh_token: auth_token.refresh_token)
      
      # Calculate new expiration times
      access_token_expires_at = new_token_data[:expires_in] ? Time.current + new_token_data[:expires_in].to_i.seconds : nil
      refresh_token_expires_at = new_token_data[:refresh_expires_in] ? Time.current + new_token_data[:refresh_expires_in].to_i.seconds : nil
      
      # Update token in database
      auth_token.update!(
        token: new_token_data[:access_token],
        refresh_token: new_token_data[:refresh_token],
        access_token_expires_at: access_token_expires_at,
        refresh_token_expires_at: refresh_token_expires_at
      )
      
      # Return new token
      render json: {
        user_access_token: new_token_data[:access_token],
        expires_in: new_token_data[:expires_in],
        refresh_token_expires_in: new_token_data[:refresh_expires_in],
        message: 'Token refreshed successfully'
      }, status: :ok
      
    rescue => e
      Rails.logger.error "Token refresh failed: #{e.message}"
      render json: { 
        error: 'Token refresh failed',
        message: e.message
      }, status: :unprocessable_entity
    end
  end

  private
  # Write your private methods here
end

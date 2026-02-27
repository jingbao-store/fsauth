class Api::V1::AuthApisController < Api::BaseController
  # POST /api/v1/auth/request
  # Create a new auth request from openclaw
  # Params: app_id (required)
  def create_request
    app_id = params[:app_id]

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
    auth_request = AuthRequest.create!(
      application_id: application.id,
      request_id: request_id,
      state: 'pending',
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
      
      # Return token and auth data
      render json: {
        state: 'authorized',
        user_access_token: auth_token.token,
        auth_data: auth_token.auth_data,
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
    
    # If authorized, include token
    if auth_request.state == 'authorized'
      auth_token = AuthToken.find_by(request_id: request_id)
      if auth_token
        response_data[:token] = auth_token.token
        response_data[:auth_data] = auth_token.auth_data
      end
    end
    
    render json: response_data
  end

  private
  # Write your private methods here
end

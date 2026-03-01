class FeishuAuthService < ApplicationService
  attr_reader :app_id, :app_secret, :redirect_uri
  
  def initialize(app_id: nil, app_secret: nil, redirect_uri: nil)
    @app_id = app_id || Figaro.env.feishu_app_id
    @app_secret = app_secret || Figaro.env.feishu_app_secret
    @redirect_uri = redirect_uri || Figaro.env.feishu_oauth_redirect_uri
  end

  # Generate OAuth authorization URL
  # @param state [String] CSRF protection state parameter (required)
  # @param scope [String, Array] OAuth scopes (default: 'offline_access' for refresh_token support)
  #   - Can be a string: 'bitable:app:readonly offline_access'
  #   - Or an array: ['bitable:app:readonly', 'offline_access']
  #   - offline_access is required to get refresh_token
  def authorization_url(state:, scope: 'offline_access')
    base_url = 'https://accounts.feishu.cn/open-apis/authen/v1/authorize'
    
    # Convert scope to space-separated string if it's an array
    scope_string = scope.is_a?(Array) ? scope.join(' ') : scope.to_s
    
    # Ensure offline_access is always included for refresh_token support
    unless scope_string.include?('offline_access')
      scope_string = "#{scope_string} offline_access".strip
    end
    
    params = {
      client_id: @app_id,
      response_type: 'code',
      redirect_uri: @redirect_uri,
      state: state,
      scope: scope_string
    }
    "#{base_url}?#{URI.encode_www_form(params)}"
  end

  # Exchange authorization code for access token
  # Using v2 API for compatibility with v2 refresh token endpoint
  # https://open.feishu.cn/document/server-docs/authentication-management/access-token/oauth2-access-token
  def exchange_code_for_token(code:)
    url = 'https://open.feishu.cn/open-apis/authen/v2/oauth/token'
    
    response = HTTParty.post(url, {
      headers: { 'Content-Type' => 'application/json' },
      body: {
        grant_type: 'authorization_code',
        code: code,
        client_id: @app_id,
        client_secret: @app_secret,
        redirect_uri: @redirect_uri
      }.to_json
    })
    
    data = response.parsed_response
    Rails.logger.debug "Feishu token exchange response: #{data.inspect}"
    
    # v2 API returns error with 'error' field, success without it
    if data['error']
      error_msg = data['error_description'] || data['error']
      Rails.logger.error "Feishu token exchange failed: error=#{data['error']}, msg=#{error_msg}, response=#{response.body}"
      raise "Feishu OAuth failed: [#{data['error']}] #{error_msg}"
    end
    
    # v2 API returns data directly (not wrapped in {code: 0, data: {...}})
    data
  end

  # Get user info with access token
  def get_user_info(access_token:)
    url = 'https://open.feishu.cn/open-apis/authen/v1/user_info'
    
    response = HTTParty.get(url, {
      headers: { 
        'Authorization' => "Bearer #{access_token}",
        'Content-Type' => 'application/json'
      }
    })
    
    if response.success? && response.parsed_response['code'] == 0
      response.parsed_response['data']
    else
      error_msg = response.parsed_response['msg'] || 'Unknown error'
      error_code = response.parsed_response['code']
      Rails.logger.error "Feishu user info failed: code=#{error_code}, msg=#{error_msg}, response=#{response.body}"
      raise "Failed to get user info: [#{error_code}] #{error_msg}"
    end
  end

  # Refresh user access token
  # https://open.feishu.cn/document/authentication-management/access-token/refresh-user-access-token
  # NOTE: v2 API returns data directly, not wrapped in {code: 0, data: {...}}
  # NOTE: v2 API uses client_id/client_secret (different from v1's app_id/app_secret)
  def refresh_user_access_token(refresh_token:)
    url = 'https://open.feishu.cn/open-apis/authen/v2/oauth/token'
    
    response = HTTParty.post(url, {
      headers: { 'Content-Type': 'application/json' },
      body: {
        grant_type: 'refresh_token',
        client_id: @app_id,
        client_secret: @app_secret,
        refresh_token: refresh_token
      }.to_json
    })
    
    data = response.parsed_response
    Rails.logger.debug "Feishu refresh token response: #{data.inspect}"
    
    # v2 API returns error with 'error' field, success without it
    if data['error']
      error_msg = data['error_description'] || data['error']
      Rails.logger.error "Feishu token refresh failed: error=#{data['error']}, msg=#{error_msg}, response=#{response.body}"
      raise "Failed to refresh token: [#{data['error']}] #{error_msg}"
    end
    
    # Success: return token data directly
    {
      access_token: data['access_token'],
      expires_in: data['expires_in'],
      refresh_token: data['refresh_token'],
      refresh_expires_in: data['refresh_token_expires_in']
    }
  end
end

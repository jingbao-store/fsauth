class FeishuAuthService < ApplicationService
  attr_reader :app_id, :app_secret, :redirect_uri
  
  def initialize(app_id: nil, app_secret: nil, redirect_uri: nil)
    @app_id = app_id || Figaro.env.feishu_app_id
    @app_secret = app_secret || Figaro.env.feishu_app_secret
    @redirect_uri = redirect_uri || Figaro.env.feishu_oauth_redirect_uri
  end

  # Generate OAuth authorization URL
  def authorization_url(state:)
    base_url = 'https://accounts.feishu.cn/open-apis/authen/v1/authorize'
    params = {
      client_id: @app_id,
      response_type: 'code',
      redirect_uri: @redirect_uri,
      state: state
    }
    "#{base_url}?#{URI.encode_www_form(params)}"
  end

  # Exchange authorization code for access token
  def exchange_code_for_token(code:)
    url = 'https://open.feishu.cn/open-apis/authen/v1/access_token'
    
    response = HTTParty.post(url, {
      headers: { 'Content-Type' => 'application/json' },
      body: {
        grant_type: 'authorization_code',
        code: code,
        app_id: @app_id,
        app_secret: @app_secret
      }.to_json
    })
    
    if response.success? && response.parsed_response['code'] == 0
      response.parsed_response['data']
    else
      error_msg = response.parsed_response['msg'] || response.parsed_response['message'] || 'Unknown error'
      error_code = response.parsed_response['code']
      Rails.logger.error "Feishu token exchange failed: code=#{error_code}, msg=#{error_msg}, response=#{response.body}"
      raise "Feishu OAuth failed: [#{error_code}] #{error_msg}"
    end
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
  def refresh_user_access_token(refresh_token:)
    url = 'https://open.feishu.cn/open-apis/authen/v2/oauth/token'
    
    response = HTTParty.post(url, {
      headers: { 'Content-Type' => 'application/json' },
      body: {
        grant_type: 'refresh_token',
        client_id: @app_id,
        client_secret: @app_secret,
        refresh_token: refresh_token
      }.to_json
    })
    
    if response.success? && response.parsed_response['code'] == 0
      data = response.parsed_response
      {
        access_token: data['access_token'],
        expires_in: data['expires_in'],
        refresh_token: data['refresh_token'],
        refresh_token_expires_in: data['refresh_token_expires_in']
      }
    else
      error_msg = response.parsed_response['error_description'] || response.parsed_response['msg'] || 'Unknown error'
      error_code = response.parsed_response['code'] || response.parsed_response['error']
      Rails.logger.error "Feishu token refresh failed: code=#{error_code}, msg=#{error_msg}, response=#{response.body}"
      raise "Failed to refresh token: [#{error_code}] #{error_msg}"
    end
  end
end

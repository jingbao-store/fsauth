class RefreshTokenRenewalJob < ApplicationJob
  queue_as :default

  # 提前 1 天续期
  RENEWAL_THRESHOLD = 1.day

  def perform
    Rails.logger.info "[RefreshTokenRenewal] Starting..."
    
    # 查找即将过期的 refresh_token（1 天内过期且未过期）
    expiring_tokens = AuthToken
      .where('refresh_token IS NOT NULL')
      .where('refresh_token_expires_at IS NOT NULL')
      .where('refresh_token_expires_at <= ?', RENEWAL_THRESHOLD.from_now)
      .where('refresh_token_expires_at > ?', Time.current)
    
    Rails.logger.info "[RefreshTokenRenewal] Found #{expiring_tokens.count} tokens to renew"
    
    success_count = 0
    failure_count = 0
    
    expiring_tokens.find_each do |auth_token|
      renew_token(auth_token)
      success_count += 1
    rescue => e
      Rails.logger.error "[RefreshTokenRenewal] Failed for token #{auth_token.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      failure_count += 1
    end
    
    Rails.logger.info "[RefreshTokenRenewal] Completed: #{success_count} success, #{failure_count} failed"
  end
  
  private
  
  def renew_token(auth_token)
    application = auth_token.application
    
    service = FeishuAuthService.new(
      app_id: application.feishu_app_id,
      app_secret: application.feishu_app_secret,
      redirect_uri: application.redirect_url
    )
    
    new_token_data = service.refresh_user_access_token(refresh_token: auth_token.refresh_token)
    
    auth_token.update!(
      token: new_token_data[:access_token],
      refresh_token: new_token_data[:refresh_token],
      access_token_expires_at: new_token_data[:expires_in] ? Time.current + new_token_data[:expires_in].to_i.seconds : nil,
      refresh_token_expires_at: new_token_data[:refresh_expires_in] ? Time.current + new_token_data[:refresh_expires_in].to_i.seconds : nil,
      auth_data: auth_token.auth_data.merge(
        expires_in: new_token_data[:expires_in],
        refresh_expires_in: new_token_data[:refresh_expires_in],
        last_auto_renewed_at: Time.current.iso8601
      )
    )
    
    Rails.logger.info "[RefreshTokenRenewal] Renewed token #{auth_token.id}, new expiry: #{auth_token.refresh_token_expires_at}"
  end
end

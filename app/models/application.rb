class Application < ApplicationRecord
  belongs_to :user
  has_many :auth_requests, dependent: :destroy
  has_many :auth_tokens, dependent: :destroy

  validates :name, presence: true
  validates :feishu_app_id, uniqueness: true, allow_nil: true
  validates :feishu_app_secret, presence: true, if: :feishu_app_id?

  # Generate redirect URL for this application
  # Use PUBLIC_HOST from config or fall back to localhost
  def redirect_url(base_url: nil)
    base = base_url || Rails.application.config.x.public_host.presence || 'http://localhost:3000'
    "#{base}/auth/feishu/callback/#{id}"
  end

  # Check if credentials are configured
  def credentials_configured?
    feishu_app_id.present? && feishu_app_secret.present?
  end

  # Generate SKILL.md URL (public, no token)
  def skill_url(base_url: nil)
    base = base_url || Rails.application.config.x.public_host.presence || 'http://localhost:3000'
    "#{base}/applications/#{id}/SKILL.md"
  end
end

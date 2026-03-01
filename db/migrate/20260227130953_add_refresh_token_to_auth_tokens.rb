class AddRefreshTokenToAuthTokens < ActiveRecord::Migration[7.2]
  def change
    add_column :auth_tokens, :refresh_token, :text
    add_column :auth_tokens, :access_token_expires_at, :datetime
    add_column :auth_tokens, :refresh_token_expires_at, :datetime

  end
end

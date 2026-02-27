class CreateAuthTokens < ActiveRecord::Migration[7.2]
  def change
    create_table :auth_tokens do |t|
      t.text :token
      t.string :request_id
      t.text :auth_data
      t.datetime :used_at


      t.timestamps
    end
  end
end

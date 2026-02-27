class CreateAuthRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :auth_requests do |t|
      t.string :request_id
      t.string :callback_url
      t.string :state, default: "pending"
      t.datetime :expires_at

      t.index :request_id, unique: true

      t.timestamps
    end
  end
end

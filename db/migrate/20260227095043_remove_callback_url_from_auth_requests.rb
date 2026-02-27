class RemoveCallbackUrlFromAuthRequests < ActiveRecord::Migration[7.2]
  def change
    remove_column :auth_requests, :callback_url, :string
  end
end

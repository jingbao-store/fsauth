class AddScopeToAuthRequests < ActiveRecord::Migration[7.2]
  def change
    add_column :auth_requests, :scope, :text

  end
end

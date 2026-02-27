class AddApplicationIdToAuthRequests < ActiveRecord::Migration[7.2]
  def change
    add_reference :auth_requests, :application, null: false, foreign_key: true, type: :uuid
  end
end

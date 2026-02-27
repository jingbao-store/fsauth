class CreateApplications < ActiveRecord::Migration[7.2]
  def change
    create_table :applications, id: :uuid do |t|
      t.string :name, null: false, default: "Untitled"
      t.string :feishu_app_id
      t.string :feishu_app_secret
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :applications, :feishu_app_id, unique: true
  end
end

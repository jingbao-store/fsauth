class AddSkillTokenToApplications < ActiveRecord::Migration[7.2]
  def change
    add_column :applications, :skill_token, :string

    add_index :applications, :skill_token, unique: true
  end
end

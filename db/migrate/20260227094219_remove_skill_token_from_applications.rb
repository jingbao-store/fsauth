class RemoveSkillTokenFromApplications < ActiveRecord::Migration[7.2]
  def change
    remove_column :applications, :skill_token, :string
  end
end

class AddUniqueIndexToAuthTokensApplicationId < ActiveRecord::Migration[7.2]
  def change
    # Remove duplicate auth_tokens, keep only the most recent one per application
    # This ensures we can add the unique constraint
    reversible do |dir|
      dir.up do
        # Find and delete older duplicate tokens for each application
        execute <<-SQL
          DELETE FROM auth_tokens
          WHERE id NOT IN (
            SELECT MAX(id)
            FROM auth_tokens
            GROUP BY application_id
          )
        SQL
      end
    end
    
    # Remove existing non-unique index
    remove_index :auth_tokens, :application_id, if_exists: true
    
    # Add unique index to ensure one token per application
    add_index :auth_tokens, :application_id, unique: true
  end
end

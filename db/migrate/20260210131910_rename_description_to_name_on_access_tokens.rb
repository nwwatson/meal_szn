class RenameDescriptionToNameOnAccessTokens < ActiveRecord::Migration[8.1]
  def change
    rename_column :access_tokens, :description, :name
  end
end

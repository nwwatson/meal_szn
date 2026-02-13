class CreateRecipeTags < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_tags, id: :string do |t|
      t.string :recipe_id, null: false
      t.string :tag_id, null: false

      t.timestamps
    end

    add_index :recipe_tags, %i[recipe_id tag_id], unique: true
    add_foreign_key :recipe_tags, :recipes
    add_foreign_key :recipe_tags, :tags
  end
end

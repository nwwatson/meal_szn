class CreateRecipeTips < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_tips, id: :string do |t|
      t.references :recipe, null: false, foreign_key: true, type: :string
      t.text :tip, null: false

      t.timestamps
    end
  end
end

class CreateRecipeInstructions < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_instructions, id: :string do |t|
      t.references :recipe, null: false, foreign_key: true, type: :string
      t.integer :step_number, null: false
      t.text :instruction, null: false

      t.timestamps
    end

    add_index :recipe_instructions, [ :recipe_id, :step_number ], unique: true
  end
end

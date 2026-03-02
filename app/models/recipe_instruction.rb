class RecipeInstruction < ApplicationRecord
  include Identifiable

  belongs_to :recipe, touch: true

  validates :step_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :instruction, presence: true
  validates :step_number, uniqueness: { scope: :recipe_id }

  default_scope { order(:step_number) }

  def to_api_response
    {
      step_number: step_number,
      instruction: instruction
    }
  end
end

class RecipeTag < ApplicationRecord
  include Identifiable

  belongs_to :recipe
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :recipe_id }
end

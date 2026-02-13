class RecipeNutritionData < ApplicationRecord
  include Identifiable

  belongs_to :recipe

  validates :recipe_id, uniqueness: true

  before_save :calculate_net_carbs

  def to_api_response
    {
      calories: calories,
      fat: fat&.to_f,
      protein: protein&.to_f,
      carbs: carbs&.to_f,
      fiber: fiber&.to_f,
      net_carbs: net_carbs&.to_f,
      sodium: sodium,
      potassium: potassium,
      magnesium: magnesium
    }
  end

  def to_meal_planning_response
    {
      calories: calories,
      fat_g: fat&.to_f,
      protein_g: protein&.to_f,
      net_carbs_g: net_carbs&.to_f,
      fiber_g: fiber&.to_f,
      sodium_mg: sodium,
      potassium_mg: potassium,
      magnesium_mg: magnesium
    }
  end

  private

  def calculate_net_carbs
    if carbs.present? && fiber.present?
      self.net_carbs = carbs - fiber
    elsif carbs.present?
      self.net_carbs = carbs
    end
  end
end

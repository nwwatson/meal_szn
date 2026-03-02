class MealPlanMeal < ApplicationRecord
  include Identifiable

  belongs_to :meal_plan_day, touch: true
  belongs_to :recipe
  has_many :portions, class_name: "MealPlanMealPortion", dependent: :destroy

  validates :meal_type, presence: true
  validates :servings, numericality: { greater_than: 0 }

  enum :meal_type, {
    breakfast: 0,
    lunch: 1,
    dinner: 2,
    snack: 3
  }

  def calories
    (recipe.nutrition_data&.calories.to_i * servings).round
  end

  def to_api_response
    {
      meal_type: meal_type,
      servings: servings.to_f,
      recipe: {
        id: recipe.id,
        title: recipe.title,
        category: recipe.category
      },
      nutrition: {
        calories: calories,
        fat_g: (recipe.nutrition_data&.fat.to_f * servings).round(1),
        protein_g: (recipe.nutrition_data&.protein.to_f * servings).round(1),
        net_carbs_g: (recipe.nutrition_data&.net_carbs.to_f * servings).round(1)
      }
    }
  end
end

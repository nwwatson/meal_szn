class MealPlanDay < ApplicationRecord
  include Identifiable

  belongs_to :meal_plan
  has_many :meals, class_name: "MealPlanMeal", dependent: :destroy

  validates :date, presence: true, uniqueness: { scope: :meal_plan_id }
  validates :day_number, presence: true, uniqueness: { scope: :meal_plan_id }

  accepts_nested_attributes_for :meals, allow_destroy: true

  def total_calories
    meals.includes(recipe: :nutrition_data).sum do |meal|
      (meal.recipe.nutrition_data&.calories.to_i * meal.servings).round
    end
  end

  def total_fat
    meals.includes(recipe: :nutrition_data).sum do |meal|
      (meal.recipe.nutrition_data&.fat.to_f * meal.servings).round(1)
    end
  end

  def total_protein
    meals.includes(recipe: :nutrition_data).sum do |meal|
      (meal.recipe.nutrition_data&.protein.to_f * meal.servings).round(1)
    end
  end

  def total_net_carbs
    meals.includes(recipe: :nutrition_data).sum do |meal|
      (meal.recipe.nutrition_data&.net_carbs.to_f * meal.servings).round(1)
    end
  end

  def to_api_response
    {
      day_number: day_number,
      date: date,
      meals: meals.includes(recipe: :nutrition_data).map(&:to_api_response),
      totals: {
        calories: total_calories,
        fat_g: total_fat,
        protein_g: total_protein,
        net_carbs_g: total_net_carbs
      }
    }
  end
end

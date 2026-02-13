class MealPlanParticipant < ApplicationRecord
  include Identifiable

  belongs_to :meal_plan
  belongs_to :dietary_profile
  has_many :portions, class_name: "MealPlanMealPortion", dependent: :destroy

  validates :dietary_profile_id, uniqueness: { scope: :meal_plan_id }

  delegate :name, :diet_name, :daily_calories_target, :diet, :macro_targets, to: :dietary_profile

  def daily_totals_for(day)
    day_portions = portions.joins(:meal_plan_meal).where(meal_plan_meals: { meal_plan_day_id: day.id })

    totals = { calories: 0.0, fat_g: 0.0, protein_g: 0.0, net_carbs_g: 0.0 }

    day_portions.includes(meal_plan_meal: { recipe: :nutrition_data }).each do |portion|
      nutrition = portion.meal_plan_meal.recipe.nutrition_data
      next unless nutrition

      totals[:calories] += (nutrition.calories.to_f * portion.servings).round
      totals[:fat_g] += (nutrition.fat.to_f * portion.servings).round(1)
      totals[:protein_g] += (nutrition.protein.to_f * portion.servings).round(1)
      totals[:net_carbs_g] += (nutrition.net_carbs.to_f * portion.servings).round(1)
    end

    totals
  end
end

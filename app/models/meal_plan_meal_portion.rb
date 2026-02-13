class MealPlanMealPortion < ApplicationRecord
  include Identifiable

  belongs_to :meal_plan_meal
  belongs_to :meal_plan_participant

  validates :servings, numericality: { greater_than: 0 }
  validates :meal_plan_participant_id, uniqueness: { scope: :meal_plan_meal_id }
end

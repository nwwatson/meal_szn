# frozen_string_literal: true

class MealPlanGenerationJob < AiBaseJob
  private

  def execute(meal_plan_id:, preferences: [], special_requests: nil)
    meal_plan = MealPlan.find(meal_plan_id)

    generator = MealPlanGenerator.new(
      meal_plan,
      preferences: preferences,
      special_requests: special_requests
    )

    generator.generate { |pct| update_progress(pct) }
  end
end

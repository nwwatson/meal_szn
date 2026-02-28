# frozen_string_literal: true

class GenerateMealPlanTool < ApplicationTool
  tool_name "generate_meal_plan"
  description "Create a meal plan and use AI to automatically assign recipes to each meal. " \
              "Returns a task_id to poll for completion via get_meal_plan once finished. " \
              "Available preferences: no_repeats, quick_weekday, skip_breakfast, skip_lunch, batch_cook_sunday, high_variety."

  arguments do
    required(:name).filled(:string).description("Name for the meal plan")
    required(:start_date).filled(:string).description("Start date in YYYY-MM-DD format")
    required(:end_date).filled(:string).description("End date in YYYY-MM-DD format")
    optional(:daily_calories_target).filled(:integer).description("Daily calorie target")
    optional(:preferences).array(:str?).description("List of preference keys: no_repeats, quick_weekday, skip_breakfast, skip_lunch, batch_cook_sunday, high_variety")
    optional(:special_requests).filled(:string).description("Freeform text for special dietary requests or constraints")
  end

  def call(name:, start_date:, end_date:, daily_calories_target: nil, preferences: [], special_requests: nil)
    plan = current_account.meal_plans.build(
      name: name,
      start_date: Date.parse(start_date),
      end_date: Date.parse(end_date),
      daily_calories_target: daily_calories_target,
      user: Current.user
    )

    unless plan.save
      return { content: [ { type: "text", text: JSON.generate({ errors: plan.errors.full_messages }) } ], isError: true }
    end

    # Generate days
    (plan.start_date..plan.end_date).each_with_index do |date, index|
      plan.days.create!(date: date, day_number: index + 1)
    end

    # Create async task and enqueue generation job
    task = current_account.ai_task_statuses.create!(task_type: "meal_plan_generation")

    MealPlanGenerationJob.perform_later(
      task.id,
      meal_plan_id: plan.id,
      preferences: preferences.reject(&:blank?),
      special_requests: special_requests.presence
    )

    {
      content: [
        {
          type: "text",
          text: JSON.generate({
            task_id: task.id,
            meal_plan_id: plan.id,
            status: "pending",
            message: "Meal plan generation started. The AI is assigning recipes to meals. " \
                     "Use get_meal_plan with meal_plan_id '#{plan.id}' to check the result once generation completes."
          })
        }
      ]
    }
  rescue Date::Error => e
    { content: [ { type: "text", text: JSON.generate({ error: "Invalid date format: #{e.message}" }) } ], isError: true }
  end
end

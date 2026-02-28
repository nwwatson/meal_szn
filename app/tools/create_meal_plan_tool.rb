# frozen_string_literal: true

class CreateMealPlanTool < ApplicationTool
  tool_name "create_meal_plan"
  description "Create a new meal plan with a date range. Days are automatically generated for each date in the range."

  arguments do
    required(:name).filled(:string).description("Name for the meal plan, e.g. 'Week of March 3'")
    required(:start_date).filled(:string).description("Start date in YYYY-MM-DD format")
    required(:end_date).filled(:string).description("End date in YYYY-MM-DD format")
    optional(:daily_calories_target).filled(:integer).description("Daily calorie target for the plan")
  end

  def call(name:, start_date:, end_date:, daily_calories_target: nil)
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

    {
      content: [
        { type: "text", text: JSON.generate({ meal_plan: plan.reload.to_api_response }) }
      ]
    }
  rescue Date::Error => e
    { content: [ { type: "text", text: JSON.generate({ error: "Invalid date format: #{e.message}" }) } ], isError: true }
  end
end

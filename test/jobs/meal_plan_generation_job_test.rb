# frozen_string_literal: true

require "test_helper"

class MealPlanGenerationJobTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @task = @account.ai_task_statuses.create!(task_type: "meal_plan_generation")
  end

  test "job is enqueued on ai queue" do
    assert_equal "ai", MealPlanGenerationJob.new.queue_name
  end

  test "job inherits from AiBaseJob" do
    assert MealPlanGenerationJob < AiBaseJob
  end
end

# frozen_string_literal: true

require "test_helper"

class RecipeImportJobTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @task = @account.ai_task_statuses.create!(task_type: "recipe_import")
  end

  test "job is enqueued on ai queue" do
    assert_equal "ai", RecipeImportJob.new.queue_name
  end

  test "job inherits from AiBaseJob" do
    assert RecipeImportJob < AiBaseJob
  end
end

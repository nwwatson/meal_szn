# frozen_string_literal: true

require "test_helper"

class DietCategorizationJobTest < ActiveSupport::TestCase
  setup do
    @recipe = recipes(:one) # salmon with nutrition data
    @account = accounts(:one)
    @task_status = ai_task_statuses(:pending_task)
  end

  test "categorizes recipe with existing nutrition data using macro analysis" do
    result = DietCategorizationJob.new.send(:execute, recipe_id: @recipe.id)

    assert_equal @recipe.id, result[:recipe_id]
    assert_equal "macro_analysis", result[:method]
    assert_kind_of Hash, result[:scores]
    assert_equal 9, result[:scores].size
  end

  test "stores diet_scores on nutrition_data after macro analysis" do
    DietCategorizationJob.new.send(:execute, recipe_id: @recipe.id)
    @recipe.nutrition_data.reload

    assert_not_nil @recipe.nutrition_data.diet_scores
    assert_equal 9, @recipe.nutrition_data.diet_scores.size
  end

  test "creates diet tags for qualifying recipes" do
    DietCategorizationJob.new.send(:execute, recipe_id: @recipe.id)
    @recipe.reload

    diet_tags = @recipe.tags.select { |t| t.name.start_with?("diet:") }
    assert_not_empty diet_tags
  end
end

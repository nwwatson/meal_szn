require "test_helper"

class MealPlanToolsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @token = identity_access_tokens(:write_token)
    @account = accounts(:one)
    @recipe = recipes(:one)
    set_current_from_token(@token)
  end

  # ===========================================================================
  # list_meal_plans
  # ===========================================================================

  test "list_meal_plans returns plans" do
    create_test_plan

    tool = ListMealPlansTool.new(headers: auth_headers)
    result = tool.call

    data = JSON.parse(result[:content].first[:text])
    assert data["meal_plans"].is_a?(Array)
    assert data["meal_plans"].any?
  end

  # ===========================================================================
  # get_meal_plan
  # ===========================================================================

  test "get_meal_plan returns full plan details" do
    plan = create_test_plan

    tool = GetMealPlanTool.new(headers: auth_headers)
    result = tool.call(meal_plan_id: plan.id)

    data = JSON.parse(result[:content].first[:text])
    assert_equal plan.id, data["meal_plan"]["id"]
    assert data["meal_plan"]["days"].is_a?(Array)
  end

  test "get_meal_plan returns error for nonexistent plan" do
    tool = GetMealPlanTool.new(headers: auth_headers)
    result = tool.call(meal_plan_id: "nonexistent")

    assert result[:isError]
  end

  # ===========================================================================
  # create_meal_plan
  # ===========================================================================

  test "create_meal_plan creates plan with days" do
    tool = CreateMealPlanTool.new(headers: auth_headers)

    assert_difference "MealPlan.count" do
      result = tool.call(
        name: "MCP Test Plan",
        start_date: Date.today.to_s,
        end_date: (Date.today + 6.days).to_s,
        daily_calories_target: 1800
      )

      data = JSON.parse(result[:content].first[:text])
      assert_equal "MCP Test Plan", data["meal_plan"]["name"]
      assert_equal 7, data["meal_plan"]["days"].length
    end
  end

  test "create_meal_plan returns error for invalid dates" do
    tool = CreateMealPlanTool.new(headers: auth_headers)

    result = tool.call(name: "Bad Plan", start_date: "not-a-date", end_date: "also-bad")

    assert result[:isError]
    data = JSON.parse(result[:content].first[:text])
    assert data["error"].include?("Invalid date")
  end

  # ===========================================================================
  # generate_meal_plan
  # ===========================================================================

  test "generate_meal_plan enqueues job and returns task_id" do
    tool = GenerateMealPlanTool.new(headers: auth_headers)

    assert_enqueued_with(job: MealPlanGenerationJob) do
      result = tool.call(
        name: "AI Plan",
        start_date: Date.today.to_s,
        end_date: (Date.today + 6.days).to_s,
        preferences: [ "no_repeats", "high_variety" ],
        special_requests: "Extra protein"
      )

      data = JSON.parse(result[:content].first[:text])
      assert data["task_id"].present?
      assert data["meal_plan_id"].present?
      assert_equal "pending", data["status"]
    end
  end

  private

  def auth_headers
    { "authorization" => "Bearer #{@token.token}" }
  end

  def set_current_from_token(token)
    identity = token.identity
    user = identity.users.first
    Current.identity = identity
    Current.account = user.account
    Current.user = user
  end

  def create_test_plan
    plan = @account.meal_plans.create!(
      user: Current.user,
      name: "Test Plan",
      start_date: Date.today,
      end_date: Date.today + 6.days
    )
    plan.days.create!(day_number: 1, date: Date.today)
    plan
  end
end

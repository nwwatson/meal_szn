require "test_helper"

class UtilityToolsTest < ActiveSupport::TestCase
  setup do
    @token = identity_access_tokens(:write_token)
    @account = accounts(:one)
    @recipe = recipes(:one)
    @nutrition = recipe_nutrition_data(:salmon_nutrition)
    set_current_from_token(@token)
  end

  # ===========================================================================
  # get_dietary_profiles
  # ===========================================================================

  test "get_dietary_profiles returns active profiles" do
    tool = GetDietaryProfilesTool.new(headers: auth_headers)
    result = tool.call

    data = JSON.parse(result[:content].first[:text])
    assert data["dietary_profiles"].is_a?(Array)
    names = data["dietary_profiles"].map { |p| p["name"] }
    assert_includes names, "Dad"
    assert_includes names, "Mom"
    assert_not_includes names, "Grandpa" # inactive
  end

  test "get_dietary_profiles includes available diets" do
    tool = GetDietaryProfilesTool.new(headers: auth_headers)
    result = tool.call

    data = JSON.parse(result[:content].first[:text])
    assert data["available_diets"].is_a?(Array)
    assert data["available_diets"].length > 0
  end

  # ===========================================================================
  # get_nutrition_info
  # ===========================================================================

  test "get_nutrition_info returns nutrition data" do
    tool = GetNutritionInfoTool.new(headers: auth_headers)
    result = tool.call(recipe_id: @recipe.id)

    data = JSON.parse(result[:content].first[:text])
    assert_equal @recipe.id, data["recipe_id"]
    assert data["nutrition_per_serving"].is_a?(Hash)
    assert data["nutrition_per_serving"]["calories"].present?
  end

  test "get_nutrition_info returns error for missing recipe" do
    tool = GetNutritionInfoTool.new(headers: auth_headers)
    result = tool.call(recipe_id: "nonexistent")

    assert result[:isError]
    data = JSON.parse(result[:content].first[:text])
    assert_equal "Recipe not found", data["error"]
  end

  # ===========================================================================
  # generate_shopping_list
  # ===========================================================================

  test "generate_shopping_list creates list from plan" do
    plan = create_plan_with_meals

    tool = GenerateShoppingListTool.new(headers: auth_headers)
    result = tool.call(meal_plan_id: plan.id)

    data = JSON.parse(result[:content].first[:text])
    assert_equal plan.id, data["meal_plan_id"]
    assert data["shopping_list"].is_a?(Hash)
    assert data["shopping_list"]["items"].is_a?(Array)
  end

  test "generate_shopping_list returns error for missing plan" do
    tool = GenerateShoppingListTool.new(headers: auth_headers)
    result = tool.call(meal_plan_id: "nonexistent")

    assert result[:isError]
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

  def create_plan_with_meals
    plan = @account.meal_plans.create!(
      user: Current.user,
      name: "Shopping Test Plan",
      start_date: Date.today,
      end_date: Date.today + 6.days
    )
    day = plan.days.create!(day_number: 1, date: Date.today)
    day.meals.create!(recipe: @recipe, meal_type: :breakfast, servings: 1)
    plan
  end
end

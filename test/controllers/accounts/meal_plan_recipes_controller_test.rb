require "test_helper"

class Accounts::MealPlanRecipesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
    @meal_plan = meal_plans(:one)
    @recipe = recipes(:one)
  end

  def account_path_prefix
    "/#{@account.external_account_id}"
  end

  test "should redirect to sign in when unauthenticated" do
    get "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/recipes/#{@recipe.id}"
    assert_response :redirect
  end

  test "should show recipe with meal plan context" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/recipes/#{@recipe.id}"
    assert_response :success
    assert_select "h1", @recipe.title
  end

  test "should have back link to meal plan" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/recipes/#{@recipe.id}"
    assert_response :success
    assert_select "a[href*='meal_plans/#{@meal_plan.id}']", text: /Back to/
  end
end

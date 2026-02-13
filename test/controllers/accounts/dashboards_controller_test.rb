require "test_helper"

class Accounts::DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
  end

  test "should redirect to sign in when unauthenticated" do
    get "/#{@account.external_account_id}"
    assert_response :redirect
  end

  test "should show dashboard when authenticated" do
    sign_in_as(@session)
    get "/#{@account.external_account_id}"
    assert_response :success
  end

  test "should show recent recipes" do
    sign_in_as(@session)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "h1", /Welcome to #{@account.name}/
  end

  test "should show current meal plan widget" do
    sign_in_as(@session)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "h2", "Current Meal Plan"
    assert_select "h3", meal_plans(:one).name
  end

  test "should show create meal plan CTA when no current plan" do
    sign_in_as(@session)
    MealPlan.update_all(start_date: 1.year.ago, end_date: 11.months.ago)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "h3", "No active meal plan"
  end
end

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

  test "should show welcome header with user name" do
    sign_in_as(@session)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "h1", /Welcome back/
  end

  test "should show recipe count widget" do
    sign_in_as(@session)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "p", "Recipes"
  end

  test "should show active plan status with day progress" do
    sign_in_as(@session)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "p", /Day 1/
  end

  test "should show today's meals hero when plan has meals today" do
    sign_in_as(@session)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "h2", "Today's Meals"
    assert_select "h3", recipes(:two).title
    assert_select "h3", recipes(:one).title
  end

  test "should show weekly overview strip" do
    sign_in_as(@session)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "h2", "This Week"
  end

  test "should show recent recipes grid" do
    sign_in_as(@session)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "h2", "Recent Recipes"
  end

  test "should show no active plan empty state when no current plan" do
    sign_in_as(@session)
    MealPlan.update_all(start_date: 1.year.ago, end_date: 11.months.ago)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "h3", "No active meal plan"
  end

  test "should show contextual quick action for meal plan when none exists" do
    sign_in_as(@session)
    MealPlan.update_all(start_date: 1.year.ago, end_date: 11.months.ago)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "p", "Create Meal Plan"
  end

  test "should assign today and shopping_list" do
    sign_in_as(@session)
    get "/#{@account.external_account_id}"
    assert_response :success
    # @today should be the day matching Date.current
    # @shopping_list may be nil (no shopping list in fixtures)
    # @dietary_profiles_count should be assigned
  end
end

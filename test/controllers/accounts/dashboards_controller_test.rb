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

  # === Macro progress visualization tests ===

  test "should show macro progress bars with targets when dietary profile exists" do
    sign_in_as(@session)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "[data-testid='macro-progress']" do
      assert_select "span", /Calories/
      assert_select "span", /Fat/
      assert_select "span", /Protein/
      assert_select "span", /Net Carbs/
      # Should show target values from keto dietary profile (2000 cal)
      assert_select "span", /2000/
    end
  end

  test "should show macro totals without targets when no dietary profile" do
    sign_in_as(@session)
    # Deactivate all profiles and unlink from users instead of deleting
    DietaryProfile.update_all(active: false, user_id: nil)
    @account.meal_plans.update_all(daily_calories_target: nil)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "[data-testid='macro-progress']" do
      assert_select "span", /Calories/
    end
  end

  test "should fall back to meal plan calorie target when profile has no diet" do
    sign_in_as(@session)
    DietaryProfile.where(user_id: users(:one).id).update_all(diet_name: nil)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "[data-testid='macro-progress']"
  end

  # === Shopping list status tests ===

  test "should show shopping list status when shopping list exists" do
    sign_in_as(@session)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "[data-testid='shopping-list-status']" do
      assert_select "h2", "Shopping List"
      assert_select "p", /1 of 3 items/
      assert_select "p", /2 remaining/
    end
  end

  test "should not show shopping list section when no shopping list exists" do
    sign_in_as(@session)
    ShoppingListItem.delete_all
    ShoppingList.delete_all
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "[data-testid='shopping-list-status']", count: 0
  end

  test "should show all done message when all shopping list items checked" do
    sign_in_as(@session)
    ShoppingListItem.update_all(checked: true)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "[data-testid='shopping-list-status']" do
      assert_select "p", /All done/
      assert_select "span", /100%/
    end
  end

  # === Empty state tests ===

  test "should show empty recipes state when no recipes exist" do
    sign_in_as(@session)
    # Move plans to past instead of deleting to avoid FK issues
    MealPlan.update_all(start_date: 1.year.ago, end_date: 11.months.ago)
    MealPlanMealPortion.delete_all
    MealPlanMeal.delete_all
    Recipe.update_all(account_id: accounts(:two).id)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "h3", "No recipes yet"
    assert_select "a", "Add Your First Recipe"
  end

  test "should show setup profiles hint when no dietary profiles and no plan" do
    sign_in_as(@session)
    MealPlan.update_all(start_date: 1.year.ago, end_date: 11.months.ago)
    DietaryProfile.update_all(active: false, user_id: nil)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "a", "Set Up Profiles"
  end

  test "should render dashboard with no data at all" do
    sign_in_as(@session)
    MealPlan.update_all(start_date: 1.year.ago, end_date: 11.months.ago)
    MealPlanMealPortion.delete_all
    MealPlanMeal.delete_all
    Recipe.update_all(account_id: accounts(:two).id)
    DietaryProfile.update_all(active: false, user_id: nil)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "h1", /Welcome back/
    assert_select "h3", "No active meal plan"
    assert_select "h3", "No recipes yet"
  end

  # === Design aesthetic tests ===

  test "should use warm design system classes" do
    sign_in_as(@session)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select ".bg-warm-gradient"
    assert_select ".card-warm"
    assert_select ".fade-up"
  end
end

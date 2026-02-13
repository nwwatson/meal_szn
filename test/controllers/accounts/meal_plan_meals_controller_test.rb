require "test_helper"

class Accounts::MealPlanMealsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
    @meal_plan = meal_plans(:one)
    @day = meal_plan_days(:day_one)
    @recipe = recipes(:one)
    @meal = meal_plan_meals(:breakfast)
  end

  def account_path_prefix
    "/#{@account.external_account_id}"
  end

  test "should create meal via HTML" do
    sign_in_as(@session)

    assert_difference "MealPlanMeal.count" do
      post "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/meals", params: {
        meal_plan_day_id: @day.id,
        meal: { recipe_id: @recipe.id, meal_type: "lunch", servings: 2 }
      }
    end

    assert_response :redirect
  end

  test "should create meal via JSON" do
    sign_in_as(@session)

    assert_difference "MealPlanMeal.count" do
      post "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/meals",
        params: {
          meal_plan_day_id: @day.id,
          meal: { recipe_id: @recipe.id, meal_type: "snack", servings: 1 }
        },
        as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "ok", json["status"]
  end

  test "should auto-create portions for participants when creating meal" do
    sign_in_as(@session)

    # The meal plan has 2 participants (dad + kid) from fixtures
    participant_count = @meal_plan.participants.count
    assert participant_count >= 2

    assert_difference "MealPlanMealPortion.count", participant_count do
      post "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/meals", params: {
        meal_plan_day_id: @day.id,
        meal: { recipe_id: @recipe.id, meal_type: "lunch", servings: 2 }
      }
    end
  end

  test "should destroy meal" do
    sign_in_as(@session)

    assert_difference "MealPlanMeal.count", -1 do
      delete "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/meals/#{@meal.id}"
    end

    assert_response :redirect
  end
end

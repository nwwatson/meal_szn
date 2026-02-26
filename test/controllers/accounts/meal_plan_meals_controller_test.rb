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

  test "should move meal to different day via JSON" do
    sign_in_as(@session)
    day_two = meal_plan_days(:day_two)

    patch "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/meals/#{@meal.id}/move",
      params: { target_day_id: day_two.id, target_meal_type: "breakfast" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "ok", json["status"]
    assert_equal day_two.id, @meal.reload.meal_plan_day_id
  end

  test "should move meal to different meal type" do
    sign_in_as(@session)

    patch "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/meals/#{@meal.id}/move",
      params: { target_day_id: @day.id, target_meal_type: "lunch" },
      as: :json

    assert_response :success
    assert_equal "lunch", @meal.reload.meal_type
  end

  test "should move meal to different day and meal type" do
    sign_in_as(@session)
    day_two = meal_plan_days(:day_two)

    patch "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/meals/#{@meal.id}/move",
      params: { target_day_id: day_two.id, target_meal_type: "dinner" },
      as: :json

    assert_response :success
    @meal.reload
    assert_equal day_two.id, @meal.meal_plan_day_id
    assert_equal "dinner", @meal.meal_type
  end

  test "move via HTML redirects back" do
    sign_in_as(@session)
    day_two = meal_plan_days(:day_two)

    patch "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/meals/#{@meal.id}/move",
      params: { target_day_id: day_two.id, target_meal_type: "breakfast" },
      headers: { "HTTP_REFERER" => "#{account_path_prefix}/meal_plans/#{@meal_plan.id}" }

    assert_response :redirect
    assert_equal day_two.id, @meal.reload.meal_plan_day_id
  end

  test "move with invalid day returns not found" do
    sign_in_as(@session)

    patch "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/meals/#{@meal.id}/move",
      params: { target_day_id: "nonexistent", target_meal_type: "breakfast" },
      as: :json

    assert_response :not_found
  end
end

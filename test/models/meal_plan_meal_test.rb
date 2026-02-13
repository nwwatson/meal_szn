require "test_helper"

class MealPlanMealTest < ActiveSupport::TestCase
  test "belongs to meal_plan_day" do
    meal = meal_plan_meals(:breakfast)
    assert_equal meal_plan_days(:day_one), meal.meal_plan_day
  end

  test "belongs to recipe" do
    meal = meal_plan_meals(:breakfast)
    assert_equal recipes(:two), meal.recipe
  end

  test "requires meal_type" do
    meal = MealPlanMeal.new(meal_plan_day: meal_plan_days(:day_two), recipe: recipes(:side_dish), meal_type: nil)
    assert_not meal.valid?
    assert_includes meal.errors[:meal_type], "can't be blank"
  end

  test "servings must be greater than 0" do
    meal = MealPlanMeal.new(
      meal_plan_day: meal_plan_days(:day_two),
      recipe: recipes(:side_dish),
      meal_type: :snack,
      servings: 0
    )
    assert_not meal.valid?
    assert_includes meal.errors[:servings], "must be greater than 0"
  end

  test "meal_type enum" do
    assert_equal %w[breakfast lunch dinner snack], MealPlanMeal.meal_types.keys
  end

  test "calories calculation" do
    meal = meal_plan_meals(:dinner)
    # salmon nutrition: 450 cal, servings: 1.5
    assert_equal 675, meal.calories
  end

  test "calories returns 0 when no nutrition data" do
    meal = MealPlanMeal.new(
      meal_plan_day: meal_plan_days(:day_two),
      recipe: recipes(:side_dish),
      meal_type: :snack,
      servings: 1
    )
    assert_equal 0, meal.calories
  end

  test "to_api_response includes meal_type, servings, recipe, nutrition" do
    meal = meal_plan_meals(:breakfast)
    response = meal.to_api_response
    assert_equal "breakfast", response[:meal_type]
    assert_equal 1.0, response[:servings]
    assert response[:recipe].is_a?(Hash)
    assert response[:nutrition].is_a?(Hash)
    assert_equal 320, response[:nutrition][:calories]
  end

  test "generates UUID id on create" do
    meal = MealPlanMeal.create!(
      meal_plan_day: meal_plan_days(:day_two),
      recipe: recipes(:side_dish),
      meal_type: :snack,
      servings: 1
    )
    assert meal.id.present?
  end
end

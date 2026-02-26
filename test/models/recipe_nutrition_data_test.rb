require "test_helper"

class RecipeNutritionDataTest < ActiveSupport::TestCase
  test "belongs to recipe" do
    nutrition = recipe_nutrition_data(:salmon_nutrition)
    assert_equal recipes(:one), nutrition.recipe
  end

  test "recipe can only have one nutrition data" do
    recipe = recipes(:one)
    duplicate = RecipeNutritionData.new(recipe: recipe, calories: 400)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:recipe_id], "has already been taken"
  end

  test "calculates net_carbs from carbs and fiber" do
    nutrition = recipe_nutrition_data(:cauliflower_nutrition)
    nutrition.update!(carbs: 10, fiber: 3)

    assert_equal 7, nutrition.net_carbs
  end

  test "net_carbs equals carbs when fiber is nil" do
    nutrition = recipe_nutrition_data(:cauliflower_nutrition)
    nutrition.update!(carbs: 10, fiber: nil)

    assert_equal 10, nutrition.net_carbs
  end

  test "to_api_response includes all nutrition fields" do
    nutrition = recipe_nutrition_data(:salmon_nutrition)
    response = nutrition.to_api_response

    assert_equal 450, response[:calories]
    assert_equal 28.0, response[:fat]
    assert_equal 42.0, response[:protein]
    assert_equal 2.0, response[:carbs]
    assert_equal 0.0, response[:fiber]
    assert_equal 2.0, response[:net_carbs]
    assert_equal 380, response[:sodium]
    assert_equal 620, response[:potassium]
    assert_equal 45, response[:magnesium]
  end

  test "to_meal_planning_response uses correct units" do
    nutrition = recipe_nutrition_data(:salmon_nutrition)
    response = nutrition.to_meal_planning_response

    assert_equal 450, response[:calories]
    assert_equal 28.0, response[:fat_g]
    assert_equal 42.0, response[:protein_g]
    assert_equal 2.0, response[:net_carbs_g]
  end
end

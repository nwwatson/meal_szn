require "test_helper"

class NutritionCalculationJobTest < ActiveJob::TestCase
  setup do
    @account = accounts(:one)
    @recipe = @account.recipes.create!(
      title: "Test Recipe",
      category: :breakfast,
      servings: 2
    )
  end

  test "calculates and saves nutrition data for recipe" do
    egg_item = nutrition_items(:egg)
    @recipe.ingredients.create!(name: "Eggs", quantity: "4", unit: "large", nutrition_item: egg_item)

    NutritionCalculationJob.perform_now(@recipe.id)

    @recipe.reload
    assert @recipe.nutrition_data.present?
    assert @recipe.nutrition_data.auto_calculated?
    assert @recipe.nutrition_data.calories > 0
  end

  test "does nothing for recipe with no ingredients" do
    NutritionCalculationJob.perform_now(@recipe.id)

    @recipe.reload
    assert_nil @recipe.nutrition_data
  end

  test "does nothing when ingredients are unresolved" do
    @recipe.ingredients.create!(name: "Unknown exotic thing", quantity: "1", unit: "cup")

    NutritionCalculationJob.perform_now(@recipe.id)

    @recipe.reload
    assert_nil @recipe.nutrition_data
  end

  test "discards job for missing recipe" do
    assert_nothing_raised do
      NutritionCalculationJob.perform_now("nonexistent-id")
    end
  end

  test "updates existing auto-calculated nutrition data" do
    egg_item = nutrition_items(:egg)
    @recipe.ingredients.create!(name: "Eggs", quantity: "2", unit: "large", nutrition_item: egg_item)

    NutritionCalculationJob.perform_now(@recipe.id)
    @recipe.reload
    original_calories = @recipe.nutrition_data.calories

    # Add more ingredients and recalculate
    butter_item = nutrition_items(:butter)
    @recipe.ingredients.create!(name: "Butter", quantity: "2", unit: "tbsp", nutrition_item: butter_item)

    NutritionCalculationJob.perform_now(@recipe.id)
    @recipe.reload
    assert @recipe.nutrition_data.calories > original_calories
  end
end

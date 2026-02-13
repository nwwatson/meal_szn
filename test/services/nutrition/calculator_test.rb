require "test_helper"

class Nutrition::CalculatorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @recipe = @account.recipes.create!(
      title: "Test Recipe",
      category: :breakfast,
      servings: 2
    )
  end

  test "calculates nutrition for resolved ingredients" do
    egg_item = nutrition_items(:egg)
    @recipe.ingredients.create!(name: "Eggs", quantity: "4", unit: "large", nutrition_item: egg_item)

    butter_item = nutrition_items(:butter)
    @recipe.ingredients.create!(name: "Butter", quantity: "2", unit: "tbsp", nutrition_item: butter_item)

    result = Nutrition::Calculator.new(@recipe.reload).calculate
    assert result.success?

    # 4 large eggs = 200g: 143 * 2 = 286 calories
    # 2 tbsp butter = 28.4g: 717 * 0.284 = 203.6 calories
    # Total = 489.6, per serving (2) = 244.8, rounded = 245
    assert_in_delta 245, result.nutrition_data[:calories], 1
    assert result.nutrition_data[:auto_calculated]
  end

  test "returns unresolved when ingredients not matched" do
    @recipe.ingredients.create!(name: "Unknown Food", quantity: "1", unit: "cup")

    result = Nutrition::Calculator.new(@recipe.reload).calculate
    assert_not result.success?
    assert_equal 1, result.unresolved_ingredients.size
    assert_equal "Unknown Food", result.unresolved_ingredients.first.name
  end

  test "auto-links ingredient by alias name" do
    @recipe.ingredients.create!(name: "Eggs", quantity: "2", unit: "large")

    result = Nutrition::Calculator.new(@recipe.reload).calculate
    assert result.success?

    # Verify ingredient was auto-linked
    ingredient = @recipe.ingredients.first.reload
    assert_equal nutrition_items(:egg).id, ingredient.nutrition_item_id
  end

  test "skips pinch and dash units" do
    egg_item = nutrition_items(:egg)
    @recipe.ingredients.create!(name: "Eggs", quantity: "2", unit: "large", nutrition_item: egg_item)
    @recipe.ingredients.create!(name: "Salt", quantity: "1", unit: "pinch", nutrition_item: egg_item)

    result = Nutrition::Calculator.new(@recipe.reload).calculate
    # Salt with pinch unit is skipped, not unresolved
    assert result.success?
  end

  test "divides by servings" do
    egg_item = nutrition_items(:egg)
    @recipe.ingredients.create!(name: "Eggs", quantity: "4", unit: "large", nutrition_item: egg_item)

    result = Nutrition::Calculator.new(@recipe.reload).calculate
    assert result.success?

    # 4 large eggs = 200g: 143 * 2 = 286 calories total, 143 per serving (servings = 2)
    assert_in_delta 143, result.nutrition_data[:calories], 1
  end

  test "handles recipe with no servings gracefully" do
    @recipe.update!(servings: nil)
    egg_item = nutrition_items(:egg)
    @recipe.ingredients.create!(name: "Eggs", quantity: "2", unit: "large", nutrition_item: egg_item)

    result = Nutrition::Calculator.new(@recipe.reload).calculate
    assert result.success?
    assert result.nutrition_data[:calories] > 0
  end

  test "handles ingredients with nil quantity" do
    egg_item = nutrition_items(:egg)
    @recipe.ingredients.create!(name: "Eggs", quantity: nil, unit: "large", nutrition_item: egg_item)

    result = Nutrition::Calculator.new(@recipe.reload).calculate
    # nil quantity is skipped, not unresolved
    assert result.success?
  end
end

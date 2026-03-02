require "test_helper"

class FakeUsdaClientForCalculator
  attr_reader :search_result, :should_error

  def initialize(search_result: nil, should_error: false)
    @search_result = search_result
    @should_error = should_error
  end

  def search(query, page_size: 10)
    raise Usda::Client::ApiError, "API error" if should_error
    search_result
  end

  def food(fdc_id)
    raise Usda::Client::ApiError, "API error" if should_error
    {}
  end
end

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
    no_results_client = FakeUsdaClientForCalculator.new(search_result: { "foods" => [] })
    @recipe.ingredients.create!(name: "Unknown Food", quantity: "1", unit: "cup")

    result = Nutrition::Calculator.new(@recipe.reload, usda_client: no_results_client).calculate
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

  test "falls back to USDA API search when alias lookup fails" do
    fake_client = FakeUsdaClientForCalculator.new(
      search_result: {
        "foods" => [ {
          "fdcId" => 999999,
          "description" => "Chicken, breast, raw",
          "foodNutrients" => [
            { "nutrient" => { "id" => 1008 }, "amount" => 165 },
            { "nutrient" => { "id" => 1004 }, "amount" => 3.6 },
            { "nutrient" => { "id" => 1003 }, "amount" => 31.0 },
            { "nutrient" => { "id" => 1005 }, "amount" => 0.0 },
            { "nutrient" => { "id" => 1079 }, "amount" => 0.0 }
          ]
        } ]
      }
    )

    @recipe.ingredients.create!(name: "Chicken breast", quantity: "200", unit: "g")

    result = Nutrition::Calculator.new(@recipe.reload, usda_client: fake_client).calculate
    assert result.success?

    # Verify ingredient was linked
    ingredient = @recipe.ingredients.first.reload
    assert_not_nil ingredient.nutrition_item_id

    # Verify alias was created
    assert_not_nil NutritionItem::Alias.find_by(name: "chicken breast")

    # 200g of chicken breast (165 cal per 100g) = 330 total, 165 per serving (2 servings)
    assert_in_delta 165, result.nutrition_data[:calories], 1
  end

  test "handles USDA API error gracefully" do
    error_client = FakeUsdaClientForCalculator.new(should_error: true)

    @recipe.ingredients.create!(name: "Unknown exotic ingredient", quantity: "1", unit: "cup")

    result = Nutrition::Calculator.new(@recipe.reload, usda_client: error_client).calculate
    assert_not result.success?
    assert_equal 1, result.unresolved_ingredients.size
  end

  test "handles USDA API returning no results" do
    empty_client = FakeUsdaClientForCalculator.new(search_result: { "foods" => [] })

    @recipe.ingredients.create!(name: "Nonexistent food xyz", quantity: "1", unit: "cup")

    result = Nutrition::Calculator.new(@recipe.reload, usda_client: empty_client).calculate
    assert_not result.success?
    assert_equal 1, result.unresolved_ingredients.size
  end
end

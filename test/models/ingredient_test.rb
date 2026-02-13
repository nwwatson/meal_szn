require "test_helper"

class IngredientTest < ActiveSupport::TestCase
  test "belongs to recipe" do
    ingredient = ingredients(:salmon_fillet)
    assert_equal recipes(:one), ingredient.recipe
  end

  test "requires name" do
    ingredient = Ingredient.new(recipe: recipes(:one), name: nil)
    assert_not ingredient.valid?
    assert_includes ingredient.errors[:name], "can't be blank"
  end

  test "generates UUID id on create" do
    ingredient = Ingredient.create!(recipe: recipes(:side_dish), name: "Garlic")
    assert ingredient.id.present?
    assert_match(/\A[0-9a-f-]{36}\z/, ingredient.id)
  end

  test "to_api_response returns hash with name, quantity, unit" do
    ingredient = ingredients(:salmon_fillet)
    response = ingredient.to_api_response
    assert_equal "Salmon Fillet", response[:name]
    assert_equal "2", response[:quantity]
    assert_equal "lbs", response[:unit]
  end

  test "display_text with quantity, unit, and name" do
    ingredient = ingredients(:salmon_fillet)
    assert_equal "2 lbs Salmon Fillet", ingredient.display_text
  end

  test "display_text with only name" do
    ingredient = Ingredient.new(name: "Salt")
    assert_equal "Salt", ingredient.display_text
  end

  test "display_text with quantity and name but no unit" do
    ingredient = Ingredient.new(name: "Eggs", quantity: "4")
    assert_equal "4 Eggs", ingredient.display_text
  end

  test "STANDARD_UNITS contains expected units" do
    assert_includes Ingredient::STANDARD_UNITS, "cups"
    assert_includes Ingredient::STANDARD_UNITS, "tbsp"
    assert_includes Ingredient::STANDARD_UNITS, "oz"
    assert_includes Ingredient::STANDARD_UNITS, "lb"
  end

  test "METRIC_UNITS contains expected units" do
    assert_includes Ingredient::METRIC_UNITS, "ml"
    assert_includes Ingredient::METRIC_UNITS, "g"
    assert_includes Ingredient::METRIC_UNITS, "kg"
    assert_includes Ingredient::METRIC_UNITS, "l"
  end

  test "UNIVERSAL_UNITS contains expected units" do
    assert_includes Ingredient::UNIVERSAL_UNITS, "pinch"
    assert_includes Ingredient::UNIVERSAL_UNITS, "whole"
    assert_includes Ingredient::UNIVERSAL_UNITS, "piece"
  end

  test "grouped_unit_options defaults to standard first" do
    options = Ingredient.grouped_unit_options
    assert_equal "Standard", options.keys.first
  end

  test "grouped_unit_options with standard has Standard first" do
    options = Ingredient.grouped_unit_options("standard")
    assert_equal %w[Standard Metric Universal], options.keys
  end

  test "grouped_unit_options with metric has Metric first" do
    options = Ingredient.grouped_unit_options("metric")
    assert_equal %w[Metric Standard Universal], options.keys
  end
end

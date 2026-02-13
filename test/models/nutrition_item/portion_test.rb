require "test_helper"

class NutritionItem::PortionTest < ActiveSupport::TestCase
  test "validates gram_weight presence" do
    portion = NutritionItem::Portion.new(
      nutrition_item: nutrition_items(:egg),
      description: "1 medium"
    )
    assert_not portion.valid?
    assert_includes portion.errors[:gram_weight], "can't be blank"
  end

  test "validates gram_weight greater than zero" do
    portion = NutritionItem::Portion.new(
      nutrition_item: nutrition_items(:egg),
      description: "1 medium",
      gram_weight: 0
    )
    assert_not portion.valid?
    assert_includes portion.errors[:gram_weight], "must be greater than 0"
  end

  test "unit_matches? with exact unit match" do
    portion = nutrition_item_portions(:egg_large)
    assert portion.unit_matches?("large")
  end

  test "unit_matches? is case insensitive" do
    portion = nutrition_item_portions(:egg_large)
    assert portion.unit_matches?("Large")
  end

  test "unit_matches? matches against description" do
    portion = nutrition_item_portions(:egg_large)
    assert portion.unit_matches?("1 large")
  end

  test "unit_matches? returns false for non-matching unit" do
    portion = nutrition_item_portions(:egg_large)
    assert_not portion.unit_matches?("cup")
  end

  test "unit_matches? returns false for blank" do
    portion = nutrition_item_portions(:egg_large)
    assert_not portion.unit_matches?("")
    assert_not portion.unit_matches?(nil)
  end
end

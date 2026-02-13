require "test_helper"

class NutritionItemTest < ActiveSupport::TestCase
  test "find_by_name with exact alias match" do
    item = NutritionItem.find_by_name("egg")
    assert_equal nutrition_items(:egg), item
  end

  test "find_by_name with plural alias" do
    item = NutritionItem.find_by_name("eggs")
    assert_equal nutrition_items(:egg), item
  end

  test "find_by_name is case insensitive" do
    item = NutritionItem.find_by_name("Eggs")
    assert_equal nutrition_items(:egg), item
  end

  test "find_by_name returns nil for unknown name" do
    assert_nil NutritionItem.find_by_name("unicorn meat")
  end

  test "normalize_name downcases and strips" do
    assert_equal "egg", NutritionItem.normalize_name("  Egg  ")
  end

  test "normalize_name removes parentheticals" do
    assert_equal "chicken breast", NutritionItem.normalize_name("chicken breast (boneless)")
  end

  test "normalize_name removes trailing commas" do
    assert_equal "salt", NutritionItem.normalize_name("salt,")
  end

  test "normalize_name collapses whitespace" do
    assert_equal "olive oil", NutritionItem.normalize_name("olive   oil")
  end

  test "grams_for with weight unit (lb)" do
    item = nutrition_items(:egg)
    grams = item.grams_for(1.0, "lb")
    assert_in_delta 453.59, grams, 0.01
  end

  test "grams_for with USDA portion unit" do
    item = nutrition_items(:egg)
    grams = item.grams_for(4.0, "large")
    assert_in_delta 200.0, grams, 0.01
  end

  test "grams_for with tbsp for butter" do
    item = nutrition_items(:butter)
    grams = item.grams_for(2.0, "tbsp")
    assert_in_delta 28.4, grams, 0.01
  end

  test "grams_for returns nil for unknown unit" do
    item = nutrition_items(:egg)
    assert_nil item.grams_for(1.0, "bushel")
  end

  test "grams_for returns nil when quantity is nil" do
    item = nutrition_items(:egg)
    assert_nil item.grams_for(nil, "large")
  end

  test "validates fdc_id presence" do
    item = NutritionItem.new(description: "Test")
    assert_not item.valid?
    assert_includes item.errors[:fdc_id], "can't be blank"
  end

  test "validates fdc_id uniqueness" do
    item = NutritionItem.new(fdc_id: nutrition_items(:egg).fdc_id, description: "Duplicate")
    assert_not item.valid?
    assert_includes item.errors[:fdc_id], "has already been taken"
  end
end

require "test_helper"

class NutritionItem::AliasTest < ActiveSupport::TestCase
  test "validates name presence" do
    alias_record = NutritionItem::Alias.new(nutrition_item: nutrition_items(:egg))
    assert_not alias_record.valid?
    assert_includes alias_record.errors[:name], "can't be blank"
  end

  test "validates name uniqueness" do
    alias_record = NutritionItem::Alias.new(
      nutrition_item: nutrition_items(:butter),
      name: "egg"
    )
    assert_not alias_record.valid?
    assert_includes alias_record.errors[:name], "has already been taken"
  end

  test "normalizes name before validation" do
    alias_record = NutritionItem::Alias.create!(
      nutrition_item: nutrition_items(:egg),
      name: "  Large Eggs  "
    )
    assert_equal "large eggs", alias_record.name
  end

  test "belongs to nutrition item" do
    alias_record = nutrition_item_aliases(:egg)
    assert_equal nutrition_items(:egg), alias_record.nutrition_item
  end
end

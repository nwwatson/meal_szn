require "test_helper"

class ShoppingListItemTest < ActiveSupport::TestCase
  test "belongs to shopping list" do
    item = shopping_list_items(:salmon)
    assert_equal shopping_lists(:one), item.shopping_list
  end

  test "validates name presence" do
    item = ShoppingListItem.new(shopping_list: shopping_lists(:one), name: "")
    refute item.valid?
    assert_includes item.errors[:name], "can't be blank"
  end

  test "unchecked scope returns unchecked items" do
    list = shopping_lists(:one)
    unchecked = list.items.unchecked
    assert unchecked.all? { |i| !i.checked }
    assert_equal 2, unchecked.count
  end

  test "checked scope returns checked items" do
    list = shopping_lists(:one)
    checked = list.items.checked
    assert checked.all?(&:checked)
    assert_equal 1, checked.count
  end

  test "alphabetical scope orders by name" do
    list = shopping_lists(:one)
    names = list.items.alphabetical.pluck(:name)
    assert_equal names.sort, names
  end

  test "display_text with quantity and unit" do
    item = shopping_list_items(:salmon)
    assert_equal "2 lbs Salmon Fillet", item.display_text
  end

  test "display_text without quantity" do
    item = ShoppingListItem.new(name: "Salt", unit: "pinch")
    assert_equal "pinch Salt", item.display_text
  end

  test "display_text with name only" do
    item = ShoppingListItem.new(name: "Salt")
    assert_equal "Salt", item.display_text
  end
end

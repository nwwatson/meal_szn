require "test_helper"

class ShoppingListTest < ActiveSupport::TestCase
  test "belongs to account, user, and meal_plan" do
    list = shopping_lists(:one)
    assert_equal accounts(:one), list.account
    assert_equal users(:one), list.user
    assert_equal meal_plans(:one), list.meal_plan
  end

  test "has many items" do
    list = shopping_lists(:one)
    assert_equal 3, list.items.count
  end

  test "destroys items on destroy" do
    list = shopping_lists(:one)
    assert_difference "ShoppingListItem.count", -3 do
      list.destroy
    end
  end

  test "all_checked? returns false when unchecked items exist" do
    refute shopping_lists(:one).all_checked?
  end

  test "all_checked? returns true when all items checked" do
    list = shopping_lists(:one)
    list.items.update_all(checked: true)
    assert list.all_checked?
  end

  test "all_checked? returns false when no items exist" do
    list = shopping_lists(:one)
    list.items.destroy_all
    refute list.all_checked?
  end

  test "checked_count returns count of checked items" do
    assert_equal 1, shopping_lists(:one).checked_count
  end

  test "total_count returns count of all items" do
    assert_equal 3, shopping_lists(:one).total_count
  end

  test "to_api_response includes all fields" do
    list = shopping_lists(:one)
    response = list.to_api_response
    assert_equal list.id, response[:id]
    assert_equal list.name, response[:name]
    assert_equal list.meal_plan_id, response[:meal_plan_id]
    assert_equal 1, response[:checked_count]
    assert_equal 3, response[:total_count]
    assert_equal false, response[:all_checked]
    assert response[:items].is_a?(Array)
    assert_equal 3, response[:items].size
    assert response[:created_at].present?
    assert response[:updated_at].present?
  end

  test "to_api_response items are sorted alphabetically" do
    list = shopping_lists(:one)
    response = list.to_api_response
    names = response[:items].map { |i| i[:name] }
    assert_equal names.sort, names
  end
end

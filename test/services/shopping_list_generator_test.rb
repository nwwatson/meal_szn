require "test_helper"

class ShoppingListGeneratorTest < ActiveSupport::TestCase
  setup do
    @meal_plan = meal_plans(:one)
    @user = users(:one)
  end

  test "generates a shopping list for the meal plan" do
    list = ShoppingListGenerator.new(@meal_plan, user: @user).generate
    assert_kind_of ShoppingList, list
    assert_equal @meal_plan, list.meal_plan
    assert_equal @user, list.user
    assert_equal @meal_plan.account, list.account
    assert list.items.any?
  end

  test "sets shopping list name" do
    list = ShoppingListGenerator.new(@meal_plan, user: @user).generate
    assert_equal "#{@meal_plan.name} Shopping List", list.name
  end

  test "aggregates items with matching name and unit" do
    # Day one has breakfast (eggs recipe: 1 serving) and dinner (salmon recipe: 1.5 servings)
    # Eggs recipe has: Eggs (4 large), Cheddar Cheese (1/2 cup)
    # Salmon recipe has: Salmon Fillet (2 lbs), Butter (2 tbsp)
    list = ShoppingListGenerator.new(@meal_plan, user: @user).generate

    item_names = list.items.pluck(:name).map(&:downcase)
    assert_includes item_names, "eggs"
    assert_includes item_names, "salmon fillet"
  end

  test "scales quantities by servings ratio" do
    list = ShoppingListGenerator.new(@meal_plan, user: @user).generate

    # Salmon recipe has 4 servings, meal has 1.5 servings
    # Salmon fillet: 2 lbs * (1.5/4) = 0.75 lbs
    salmon = list.items.find_by("LOWER(name) = ?", "salmon fillet")
    assert salmon
    assert_equal "0.75", salmon.quantity
  end

  test "creates correct number of unique items" do
    list = ShoppingListGenerator.new(@meal_plan, user: @user).generate
    # Eggs, Cheddar Cheese, Salmon Fillet, Butter = 4 unique items
    assert_equal 4, list.items.count
  end

  test "uses participant portions sum when participants exist" do
    # From fixtures: dad_dinner (1.0) + kid_dinner (0.5) = 1.5 total servings
    # Salmon recipe has 4 servings → scale = 1.5/4 = 0.375
    # Salmon fillet: 2 lbs * 0.375 = 0.75
    list = ShoppingListGenerator.new(@meal_plan, user: @user).generate
    salmon = list.items.find_by("LOWER(name) = ?", "salmon fillet")
    assert_equal "0.75", salmon.quantity
  end

  test "falls back to meal servings when no participants" do
    plan = meal_plans(:past)
    # Past plan has no participants and no meals/days with content, so use a fresh plan
    new_plan = @meal_plan.account.meal_plans.create!(
      user: @user,
      name: "No Participants Plan",
      start_date: 3.months.from_now.to_date,
      end_date: 3.months.from_now.to_date + 1.day
    )
    day = new_plan.days.create!(date: 3.months.from_now.to_date, day_number: 1)
    recipe = recipes(:one)
    day.meals.create!(recipe: recipe, meal_type: :dinner, servings: 2.0)

    assert_equal 0, new_plan.participants.count

    list = ShoppingListGenerator.new(new_plan, user: @user).generate
    salmon = list.items.find_by("LOWER(name) = ?", "salmon fillet")
    # recipe has 4 servings, meal has 2.0 → scale = 2.0/4 = 0.5
    # Salmon fillet: 2 lbs * 0.5 = 1.0
    assert_equal "1", salmon.quantity
  end
end

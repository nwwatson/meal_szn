require "test_helper"

class MealPlanDayTest < ActiveSupport::TestCase
  test "belongs to meal_plan" do
    day = meal_plan_days(:day_one)
    assert_equal meal_plans(:one), day.meal_plan
  end

  test "has many meals" do
    day = meal_plan_days(:day_one)
    assert_equal 2, day.meals.count
  end

  test "requires date" do
    day = MealPlanDay.new(meal_plan: meal_plans(:one), day_number: 99)
    assert_not day.valid?
    assert_includes day.errors[:date], "can't be blank"
  end

  test "requires day_number" do
    day = MealPlanDay.new(meal_plan: meal_plans(:one), date: 1.month.from_now.to_date)
    assert_not day.valid?
    assert_includes day.errors[:day_number], "can't be blank"
  end

  test "date unique per meal_plan" do
    existing = meal_plan_days(:day_one)
    duplicate = MealPlanDay.new(
      meal_plan: existing.meal_plan,
      date: existing.date,
      day_number: 99
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:date], "has already been taken"
  end

  test "day_number unique per meal_plan" do
    existing = meal_plan_days(:day_one)
    duplicate = MealPlanDay.new(
      meal_plan: existing.meal_plan,
      day_number: existing.day_number,
      date: 1.month.from_now.to_date
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:day_number], "has already been taken"
  end

  test "total_calories" do
    day = meal_plan_days(:day_one)
    # breakfast: eggs 1x320 + dinner: salmon 1.5x450 = 320 + 675 = 995
    assert_equal 995, day.total_calories
  end

  test "total_fat" do
    day = meal_plan_days(:day_one)
    # breakfast: 24.0*1 + dinner: 28.0*1.5 = 24.0 + 42.0 = 66.0
    assert_equal 66.0, day.total_fat
  end

  test "total_protein" do
    day = meal_plan_days(:day_one)
    # breakfast: 22.0*1 + dinner: 42.0*1.5 = 22.0 + 63.0 = 85.0
    assert_equal 85.0, day.total_protein
  end

  test "to_api_response includes day_number, date, meals, totals" do
    day = meal_plan_days(:day_one)
    response = day.to_api_response
    assert_equal 1, response[:day_number]
    assert response[:meals].is_a?(Array)
    assert response[:totals].is_a?(Hash)
    assert response[:totals][:calories].is_a?(Integer)
  end

  test "destroys meals when destroyed" do
    day = meal_plan_days(:day_one)
    meal_ids = day.meals.pluck(:id)
    assert meal_ids.any?

    day.destroy!

    meal_ids.each do |id|
      assert_not MealPlanMeal.exists?(id: id)
    end
  end
end

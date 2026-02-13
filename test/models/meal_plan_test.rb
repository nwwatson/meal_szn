require "test_helper"

class MealPlanTest < ActiveSupport::TestCase
  test "belongs to account" do
    plan = meal_plans(:one)
    assert_equal accounts(:one), plan.account
  end

  test "belongs to user" do
    plan = meal_plans(:one)
    assert_equal users(:one), plan.user
  end

  test "has many days" do
    plan = meal_plans(:one)
    assert plan.days.count >= 2
  end

  test "requires start_date" do
    plan = MealPlan.new(account: accounts(:one), user: users(:one), end_date: Date.current)
    assert_not plan.valid?
    assert_includes plan.errors[:start_date], "can't be blank"
  end

  test "requires end_date" do
    plan = MealPlan.new(account: accounts(:one), user: users(:one), start_date: Date.current)
    assert_not plan.valid?
    assert_includes plan.errors[:end_date], "can't be blank"
  end

  test "end_date must be after start_date" do
    plan = MealPlan.new(
      account: accounts(:one),
      user: users(:one),
      start_date: Date.current,
      end_date: 1.day.ago.to_date
    )
    assert_not plan.valid?
    assert_includes plan.errors[:end_date], "must be after start date"
  end

  test "duration_days" do
    plan = meal_plans(:one)
    assert_equal 7, plan.duration_days
  end

  test "total_calories sums across days and meals" do
    plan = meal_plans(:one)
    # day_one has: breakfast (eggs 1x320cal) + dinner (salmon 1.5x450cal)
    # = 320 + 675 = 995
    assert_equal 995, plan.total_calories
  end

  test "average_daily_calories" do
    plan = meal_plans(:one)
    # total_calories=995, days.count=2 → 497.5
    result = plan.average_daily_calories
    assert_in_delta 497.5, result, 0.1
  end

  test "average_daily_calories returns 0 with no days" do
    plan = meal_plans(:past)
    plan.days.destroy_all
    assert_equal 0, plan.average_daily_calories
  end

  test "to_api_response includes all fields" do
    plan = meal_plans(:one)
    response = plan.to_api_response
    assert_equal plan.id, response[:id]
    assert_equal plan.name, response[:name]
    assert_equal plan.start_date, response[:start_date]
    assert_equal plan.end_date, response[:end_date]
    assert_equal 7, response[:duration_days]
    assert response[:days].is_a?(Array)
  end

  test "generates UUID id on create" do
    plan = MealPlan.create!(
      account: accounts(:one),
      user: users(:one),
      start_date: 1.month.from_now.to_date,
      end_date: 1.month.from_now.to_date + 6.days
    )
    assert plan.id.present?
  end

  test "destroys days when destroyed" do
    plan = meal_plans(:one)
    day_ids = plan.days.pluck(:id)
    assert day_ids.any?

    plan.destroy!

    day_ids.each do |id|
      assert_not MealPlanDay.exists?(id: id)
    end
  end
end

require "test_helper"

class PortionCalculatorTest < ActiveSupport::TestCase
  setup do
    @participant = meal_plan_participants(:dad_in_current)
    @day = meal_plan_days(:day_one)
  end

  test "suggest_portions_for_day distributes by meal type" do
    calculator = PortionCalculator.new(@participant)
    portions = calculator.suggest_portions_for_day(@day)

    breakfast_meal = meal_plan_meals(:breakfast)
    dinner_meal = meal_plan_meals(:dinner)

    # Dad: 2000 cal target
    # Breakfast (25%): 500 cal allocated, eggs are 320 cal/serving → 500/320 = 1.56
    assert_in_delta 1.56, portions[breakfast_meal.id], 0.01

    # Dinner (35%): 700 cal allocated, salmon is 450 cal/serving → 700/450 = 1.56
    assert_in_delta 1.56, portions[dinner_meal.id], 0.01
  end

  test "suggest_portions_for_day clamps to range" do
    # Create a participant with very low calories to trigger min clamp
    profile = DietaryProfile.create!(
      account: accounts(:one),
      name: "Low Cal Test",
      daily_calories_target: 50
    )
    participant = @participant.meal_plan.participants.create!(dietary_profile: profile)

    calculator = PortionCalculator.new(participant)
    portions = calculator.suggest_portions_for_day(@day)

    portions.each_value do |servings|
      assert servings >= PortionCalculator::MIN_SERVINGS
      assert servings <= PortionCalculator::MAX_SERVINGS
    end

    # Cleanup
    participant.destroy
    profile.destroy
  end

  test "suggest_portions_for_day returns empty hash when no calorie target" do
    profile = dietary_profiles(:mom)
    profile.update!(daily_calories_target: nil)
    participant = @participant.meal_plan.participants.create!(dietary_profile: profile)

    calculator = PortionCalculator.new(participant)
    portions = calculator.suggest_portions_for_day(@day)
    assert_equal({}, portions)

    participant.destroy
  end

  test "suggest_portions_for_day returns empty hash for day with no meals" do
    calculator = PortionCalculator.new(@participant)
    portions = calculator.suggest_portions_for_day(meal_plan_days(:day_two))
    assert_equal({}, portions)
  end

  test "suggest_all returns portions for all days" do
    calculator = PortionCalculator.new(@participant)
    result = calculator.suggest_all

    assert result.key?(meal_plan_days(:day_one).id)
    # day_two has no meals so it should not be included
    assert_not result.key?(meal_plan_days(:day_two).id)
  end
end

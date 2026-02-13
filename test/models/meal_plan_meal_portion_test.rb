require "test_helper"

class MealPlanMealPortionTest < ActiveSupport::TestCase
  setup do
    @portion = meal_plan_meal_portions(:dad_breakfast)
  end

  test "belongs to meal_plan_meal" do
    assert_equal meal_plan_meals(:breakfast), @portion.meal_plan_meal
  end

  test "belongs to meal_plan_participant" do
    assert_equal meal_plan_participants(:dad_in_current), @portion.meal_plan_participant
  end

  test "validates servings greater than 0" do
    @portion.servings = 0
    assert_not @portion.valid?
    assert_includes @portion.errors[:servings], "must be greater than 0"
  end

  test "validates participant uniqueness per meal" do
    duplicate = MealPlanMealPortion.new(
      meal_plan_meal: @portion.meal_plan_meal,
      meal_plan_participant: @portion.meal_plan_participant,
      servings: 1.0
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:meal_plan_participant_id], "has already been taken"
  end
end

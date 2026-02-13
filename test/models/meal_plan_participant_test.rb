require "test_helper"

class MealPlanParticipantTest < ActiveSupport::TestCase
  setup do
    @participant = meal_plan_participants(:dad_in_current)
    @meal_plan = meal_plans(:one)
  end

  test "belongs to meal plan" do
    assert_equal @meal_plan, @participant.meal_plan
  end

  test "belongs to dietary profile" do
    assert_equal dietary_profiles(:dad), @participant.dietary_profile
  end

  test "has many portions" do
    assert @participant.portions.count >= 2
  end

  test "validates dietary_profile uniqueness per meal plan" do
    duplicate = @meal_plan.participants.build(dietary_profile: @participant.dietary_profile)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:dietary_profile_id], "has already been taken"
  end

  test "delegates name to dietary_profile" do
    assert_equal "Dad", @participant.name
  end

  test "delegates diet_name to dietary_profile" do
    assert_equal "Ketogenic (Keto)", @participant.diet_name
  end

  test "delegates daily_calories_target to dietary_profile" do
    assert_equal 2000, @participant.daily_calories_target
  end

  test "delegates macro_targets to dietary_profile" do
    targets = @participant.macro_targets
    assert_equal 2000, targets[:calories]
    assert targets[:fat_g] > 0
  end

  test "daily_totals_for sums portions for a day" do
    day = meal_plan_days(:day_one)
    totals = @participant.daily_totals_for(day)

    # Dad has breakfast (eggs, 320 cal * 1.5 = 480) and dinner (salmon, 450 cal * 1.0 = 450)
    assert_equal 930.0, totals[:calories]
    assert totals[:fat_g] > 0
    assert totals[:protein_g] > 0
    assert totals[:net_carbs_g] > 0
  end

  test "daily_totals_for returns zeros for day with no portions" do
    day = meal_plan_days(:day_two)
    totals = @participant.daily_totals_for(day)
    assert_equal 0.0, totals[:calories]
    assert_equal 0.0, totals[:fat_g]
  end

  test "destroying participant cascades to portions" do
    assert_difference "MealPlanMealPortion.count", -@participant.portions.count do
      @participant.destroy
    end
  end
end

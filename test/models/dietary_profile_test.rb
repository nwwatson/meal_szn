require "test_helper"

class DietaryProfileTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @profile = dietary_profiles(:dad)
  end

  test "belongs to account" do
    assert_equal @account, @profile.account
  end

  test "belongs to user optionally" do
    assert_equal users(:one), @profile.user
    assert_nil dietary_profiles(:kid).user
  end

  test "validates name presence" do
    @profile.name = ""
    assert_not @profile.valid?
    assert_includes @profile.errors[:name], "can't be blank"
  end

  test "validates name uniqueness scoped to account" do
    duplicate = @account.dietary_profiles.build(name: @profile.name)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "validates daily_calories_target numericality" do
    @profile.daily_calories_target = -100
    assert_not @profile.valid?
    assert_includes @profile.errors[:daily_calories_target], "must be greater than 0"
  end

  test "allows nil daily_calories_target" do
    @profile.daily_calories_target = nil
    assert @profile.valid?
  end

  test "allows multiple profiles without user_id" do
    profile1 = dietary_profiles(:kid)
    profile2 = @account.dietary_profiles.build(name: "Another Kid", daily_calories_target: 1200)
    assert_nil profile1.user_id
    assert profile2.valid?
  end

  test "active scope returns only active profiles" do
    active = @account.dietary_profiles.active
    assert active.include?(dietary_profiles(:dad))
    assert active.include?(dietary_profiles(:kid))
    assert_not active.include?(dietary_profiles(:inactive))
  end

  test "diet returns hash from DietRegistry" do
    diet = @profile.diet
    assert_equal "Ketogenic (Keto)", diet["name"]
  end

  test "diet returns nil when diet_name is blank" do
    @profile.diet_name = nil
    assert_nil @profile.diet
  end

  test "macro_targets computes targets" do
    targets = @profile.macro_targets
    assert_equal 2000, targets[:calories]
    assert targets[:fat_g] > 0
    assert targets[:protein_g] > 0
    assert targets[:carbs_g] > 0
  end

  test "macro_targets returns nil when no diet or calories" do
    @profile.diet_name = nil
    assert_nil @profile.macro_targets
  end

  test "linked_to_user? returns true when user_id present" do
    assert @profile.linked_to_user?
  end

  test "linked_to_user? returns false when user_id nil" do
    assert_not dietary_profiles(:kid).linked_to_user?
  end
end

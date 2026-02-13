require "test_helper"

class DietRegistryTest < ActiveSupport::TestCase
  test "all_diets returns array of diet hashes" do
    diets = DietRegistry.all_diets
    assert_kind_of Array, diets
    assert diets.size > 0
    assert diets.all? { |d| d.key?("name") }
  end

  test "diet_names returns array of name strings" do
    names = DietRegistry.diet_names
    assert_includes names, "Ketogenic (Keto)"
    assert_includes names, "Standard / USDA Guidelines"
    assert_includes names, "If It Fits Your Macros (IIFYM)"
  end

  test "find_by_name returns diet hash" do
    diet = DietRegistry.find_by_name("Ketogenic (Keto)")
    assert_equal "Ketogenic (Keto)", diet["name"]
    assert_equal 5, diet["carbs_pct"]["min"]
    assert_equal 10, diet["carbs_pct"]["max"]
  end

  test "find_by_name returns nil for unknown diet" do
    assert_nil DietRegistry.find_by_name("Imaginary Diet")
  end

  test "macro_targets_for computes gram targets from percentages" do
    targets = DietRegistry.macro_targets_for("Ketogenic (Keto)", 2000)
    assert_equal 2000, targets[:calories]

    # Fat: midpoint of 70-75 = 72.5%, 2000 * 0.725 / 9 ≈ 161.1
    assert_in_delta 161.1, targets[:fat_g], 0.1

    # Protein: midpoint of 20-25 = 22.5%, 2000 * 0.225 / 4 = 112.5
    assert_in_delta 112.5, targets[:protein_g], 0.1

    # Carbs: midpoint of 5-10 = 7.5%, 2000 * 0.075 / 4 = 37.5
    assert_in_delta 37.5, targets[:carbs_g], 0.1
  end

  test "macro_targets_for returns nil macros for IIFYM" do
    targets = DietRegistry.macro_targets_for("If It Fits Your Macros (IIFYM)", 2000)
    assert_equal 2000, targets[:calories]
    assert_nil targets[:fat_g]
    assert_nil targets[:protein_g]
    assert_nil targets[:carbs_g]
  end

  test "macro_targets_for returns nil when diet not found" do
    assert_nil DietRegistry.macro_targets_for("Nonexistent", 2000)
  end

  test "macro_targets_for returns nil when daily_calories is nil" do
    assert_nil DietRegistry.macro_targets_for("Ketogenic (Keto)", nil)
  end
end

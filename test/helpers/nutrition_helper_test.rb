require "test_helper"

class NutritionHelperTest < ActionView::TestCase
  include NutritionHelper

  # === macro_donut_chart ===

  test "macro_donut_chart renders conic-gradient with correct percentages" do
    html = macro_donut_chart(fat_g: 70, protein_g: 25, carbs_g: 5)
    assert_match(/conic-gradient/, html)
    assert_match(/macro-donut/, html)
  end

  test "macro_donut_chart renders legend items" do
    html = macro_donut_chart(fat_g: 70, protein_g: 25, carbs_g: 5)
    assert_match(/Fat/, html)
    assert_match(/Protein/, html)
    assert_match(/Carbs/, html)
  end

  test "macro_donut_chart handles zero values" do
    html = macro_donut_chart(fat_g: 0, protein_g: 0, carbs_g: 0)
    assert_no_match(/conic-gradient/, html)
    assert_match(/bg-warm-200/, html)
  end

  test "macro_donut_chart accepts custom size" do
    html = macro_donut_chart(fat_g: 10, protein_g: 10, carbs_g: 10, size: 120)
    assert_match(/width: 120px/, html)
    assert_match(/height: 120px/, html)
  end

  test "macro_donut_chart handles nil values" do
    html = macro_donut_chart(fat_g: nil, protein_g: nil, carbs_g: nil)
    assert_no_match(/conic-gradient/, html)
  end

  # === mini_donut_chart ===

  test "mini_donut_chart renders at 48px" do
    html = mini_donut_chart(fat_g: 70, protein_g: 25, carbs_g: 5)
    assert_match(/width: 48px/, html)
  end

  # === macro_progress_bar ===

  test "macro_progress_bar renders bar with correct width" do
    html = macro_progress_bar(actual: 50, target: 100, label: "Fat", macro_key: :fat)
    assert_match(/width: 50%/, html)
    assert_match(/Fat/, html)
  end

  test "macro_progress_bar caps at 100%" do
    html = macro_progress_bar(actual: 150, target: 100, label: "Fat", macro_key: :fat)
    assert_match(/width: 100%/, html)
  end

  test "macro_progress_bar shows green when within 10% of target" do
    html = macro_progress_bar(actual: 95, target: 100, label: "Fat", macro_key: :fat)
    assert_match(/bg-green-500/, html)
  end

  test "macro_progress_bar shows amber when within 25% of target" do
    html = macro_progress_bar(actual: 80, target: 100, label: "Fat", macro_key: :fat)
    assert_match(/bg-amber-500/, html)
  end

  test "macro_progress_bar shows red when outside range" do
    html = macro_progress_bar(actual: 30, target: 100, label: "Fat", macro_key: :fat)
    assert_match(/bg-red-400/, html)
  end

  test "macro_progress_bar handles nil target" do
    html = macro_progress_bar(actual: 50, target: nil, label: "Fat", macro_key: :fat)
    assert_match(/width: 0%/, html)
    assert_match(/50g/, html)
  end

  test "macro_progress_bar handles zero target" do
    html = macro_progress_bar(actual: 50, target: 0, label: "Fat", macro_key: :fat)
    assert_match(/width: 0%/, html)
  end

  test "macro_progress_bar displays actual/target values" do
    html = macro_progress_bar(actual: 65.3, target: 80.0, label: "Fat", macro_key: :fat)
    assert_match(/65.3g/, html)
    assert_match(/80.0g/, html)
  end

  test "macro_progress_bar supports custom unit" do
    html = macro_progress_bar(actual: 1500, target: 2000, label: "Cal", macro_key: nil, unit: "")
    assert_match(/1500/, html)
    assert_match(/2000/, html)
  end

  # === diet_compatibility_badge ===

  test "diet_compatibility_badge returns keto badge for low carb ratio" do
    nd = RecipeNutritionData.new(calories: 500, fat: 40, protein: 30, carbs: 5, fiber: 2, net_carbs: 3)
    badge = diet_compatibility_badge(nd)
    assert_match(/Keto/, badge)
  end

  test "diet_compatibility_badge returns low-carb badge for moderate carb ratio" do
    nd = RecipeNutritionData.new(calories: 500, fat: 30, protein: 30, carbs: 20, fiber: 5, net_carbs: 15)
    badge = diet_compatibility_badge(nd)
    assert_match(/Low-Carb/, badge)
  end

  test "diet_compatibility_badge returns high-protein badge" do
    nd = RecipeNutritionData.new(calories: 400, fat: 10, protein: 40, carbs: 10, fiber: 2, net_carbs: 8)
    badge = diet_compatibility_badge(nd)
    assert_match(/High-Protein/, badge)
  end

  test "diet_compatibility_badge returns nil for standard macros" do
    nd = RecipeNutritionData.new(calories: 500, fat: 15, protein: 20, carbs: 60, fiber: 5, net_carbs: 55)
    assert_nil diet_compatibility_badge(nd)
  end

  test "diet_compatibility_badge returns nil for nil nutrition data" do
    assert_nil diet_compatibility_badge(nil)
  end

  test "diet_compatibility_badge returns nil for zero calories" do
    nd = RecipeNutritionData.new(calories: 0, fat: 0, protein: 0, carbs: 0)
    assert_nil diet_compatibility_badge(nd)
  end

  test "diet_compatibility_badge can return multiple badges" do
    nd = RecipeNutritionData.new(calories: 400, fat: 30, protein: 35, carbs: 3, fiber: 1, net_carbs: 2)
    badge = diet_compatibility_badge(nd)
    assert_match(/Keto/, badge)
    assert_match(/High-Protein/, badge)
  end
end

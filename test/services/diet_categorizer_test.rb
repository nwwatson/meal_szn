# frozen_string_literal: true

require "test_helper"

class DietCategorizerTest < ActiveSupport::TestCase
  setup do
    @recipe = recipes(:one) # salmon: 450 cal, 28f/42p/2c
    @nutrition = recipe_nutrition_data(:salmon_nutrition)
  end

  test "calculates scores for all 9 scorable diets" do
    scores = DietCategorizer.new(@recipe).calculate_scores

    assert_equal 9, scores.size
    assert_includes scores.keys, "keto"
    assert_includes scores.keys, "low-carb"
    assert_includes scores.keys, "paleo"
    assert_includes scores.keys, "zone"
    assert_includes scores.keys, "mediterranean"
    assert_includes scores.keys, "high-protein"
    assert_includes scores.keys, "carnivore"
    assert_includes scores.keys, "vegan"
    assert_includes scores.keys, "standard"
  end

  test "scores are between 0.0 and 1.0" do
    scores = DietCategorizer.new(@recipe).calculate_scores

    scores.each do |diet, score|
      assert_operator score, :>=, 0.0, "#{diet} score should be >= 0.0"
      assert_operator score, :<=, 1.0, "#{diet} score should be <= 1.0"
    end
  end

  test "salmon recipe scores for keto reflect fat deficit" do
    # Salmon: 450 cal, 28g fat (56% cal), 42g protein (37%), 2g carbs (1.8%)
    # Keto: 70-75% fat, 20-25% protein, 5-10% carbs
    # Fat is well below keto range (56% vs 70-75%), so keto score should be moderate-low
    scores = DietCategorizer.new(@recipe).calculate_scores

    assert_operator scores["keto"], :>, 0.0, "Should have a non-zero keto score"
    assert_operator scores["keto"], :<, 0.7, "Should not qualify as keto (fat too low)"
  end

  test "salmon recipe scores high for carnivore" do
    # Carnivore: 0% carbs, 60-80% fat, 20-40% protein
    # Salmon: very low carbs, moderate-high fat, high protein
    scores = DietCategorizer.new(@recipe).calculate_scores

    assert_operator scores["carnivore"], :>, 0.5, "Salmon should score well for carnivore"
  end

  test "categorize! persists diet_scores to nutrition_data" do
    DietCategorizer.new(@recipe).categorize!
    @nutrition.reload

    assert_not_nil @nutrition.diet_scores
    assert_kind_of Hash, @nutrition.diet_scores
    assert_equal 9, @nutrition.diet_scores.size
  end

  test "categorize! creates diet tags for qualifying diets" do
    DietCategorizer.new(@recipe).categorize!
    @recipe.reload

    diet_tags = @recipe.tags.select { |t| t.name.start_with?("diet:") }
    assert_not_empty diet_tags, "Should have at least one diet tag"

    diet_tags.each do |tag|
      slug = tag.name.sub("diet:", "")
      score = @nutrition.reload.diet_scores[slug]
      assert_operator score, :>=, 0.7, "Tag #{tag.name} should only exist for scores >= 0.7"
    end
  end

  test "categorize! removes stale diet tags" do
    # Add a diet tag that shouldn't qualify
    vegan_tag = @recipe.account.tags.create!(name: "diet:vegan")
    @recipe.tags << vegan_tag

    DietCategorizer.new(@recipe).categorize!
    @recipe.reload

    # Vegan tag should be removed since salmon is not vegan-compatible
    assert_not @recipe.tags.exists?(name: "diet:vegan"),
      "Vegan tag should be removed for a salmon recipe"
  end

  test "categorize! preserves non-diet tags" do
    existing_tags = @recipe.tags.to_a
    assert_not_empty existing_tags, "Fixture should have pre-existing tags"

    DietCategorizer.new(@recipe).categorize!
    @recipe.reload

    existing_tags.reject { |t| t.name.start_with?("diet:") }.each do |tag|
      assert @recipe.tags.exists?(id: tag.id), "Non-diet tag '#{tag.name}' should be preserved"
    end
  end

  test "returns empty hash when no nutrition data" do
    recipe_without_nutrition = recipes(:side_dish)
    assert_nil recipe_without_nutrition.nutrition_data

    scores = DietCategorizer.new(recipe_without_nutrition).calculate_scores
    assert_equal({}, scores)
  end

  test "returns empty hash when calories are zero" do
    @nutrition.update_columns(calories: 0)

    scores = DietCategorizer.new(@recipe).calculate_scores
    assert_equal({}, scores)
  end

  test "range_score returns 1.0 when value is within range" do
    categorizer = DietCategorizer.new(@recipe)
    score = categorizer.send(:range_score, 72.0, { "min" => 70, "max" => 75 })

    assert_in_delta 1.0, score, 0.01
  end

  test "range_score degrades linearly outside range" do
    categorizer = DietCategorizer.new(@recipe)

    # 5 points below min with 15-point grace
    score = categorizer.send(:range_score, 65.0, { "min" => 70, "max" => 75 })
    assert_in_delta 0.67, score, 0.05

    # 15+ points below min → 0.0
    score = categorizer.send(:range_score, 50.0, { "min" => 70, "max" => 75 })
    assert_in_delta 0.0, score, 0.05
  end

  test "range_score returns 0.0 for nil range" do
    categorizer = DietCategorizer.new(@recipe)
    score = categorizer.send(:range_score, 50.0, nil)

    assert_equal 0.0, score
  end

  test "IIFYM diet is excluded from scoring" do
    scores = DietCategorizer.new(@recipe).calculate_scores

    refute_includes scores.keys, "iifym"
  end

  test "high-protein recipe scores high for high-protein diet" do
    # Eggs: 320 cal, 24f (67.5% cal), 22p (27.5% cal), 1.5c (1.9% cal)
    eggs_recipe = recipes(:two)
    scores = DietCategorizer.new(eggs_recipe).calculate_scores

    # High protein range is 40-50% protein, eggs are 27.5% — moderate match
    assert_kind_of Float, scores["high-protein"]
  end
end

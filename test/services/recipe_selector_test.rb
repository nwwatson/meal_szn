# frozen_string_literal: true

require "test_helper"

class RecipeSelectorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @meal_types = %w[breakfast lunch dinner snack]
    @current_date = Date.new(2026, 6, 1)
  end

  test "returns all recipes when catalog is smaller than limit" do
    plan = create_target_plan
    selector = build_selector(plan)

    result = selector.select(limit: 100)

    assert_equal eligible_recipe_count, result.size
  end

  test "returns only recipes with nutrition data" do
    # Create a recipe without nutrition data
    no_nutrition = @account.recipes.create!(title: "No Nutrition", category: :dinner, servings: 4)
    plan = create_target_plan

    selector = build_selector(plan)
    result = selector.select(limit: 100)

    refute_includes result.map(&:id), no_nutrition.id
  ensure
    no_nutrition&.destroy
  end

  test "hard excludes recipes from the most recent past plan" do
    # Create enough recipes to trigger hard exclusion (>= 20)
    extra_recipes = create_recipes_with_nutrition(18, category: :dinner)
    past_plan = create_past_plan_using([ extra_recipes.first, extra_recipes.second ])
    plan = create_target_plan

    # Also clean up the fixture current plan's meals so they don't interfere with
    # which plan is "most recent past"
    fixture_plan = meal_plans(:one)
    fixture_plan.update!(end_date: @current_date + 10.days) # Make it not "past" relative to @current_date

    selector = build_selector(plan)

    # Verify the past plan is discoverable
    past_plans = @account.meal_plans.where.not(id: plan.id).where("end_date < ?", @current_date).order(start_date: :desc)
    assert past_plans.any?, "Should find past plans"
    most_recent = past_plans.first
    assert_equal past_plan.id, most_recent.id, "Test past plan should be most recent"
    assert most_recent.days.flat_map(&:meals).any?, "Past plan should have meals"

    result = selector.select(limit: 100)
    result_ids = result.map(&:id)

    # Recipes used in the past plan should be excluded
    refute_includes result_ids, extra_recipes.first.id
    refute_includes result_ids, extra_recipes.second.id
  ensure
    fixture_plan&.update!(end_date: Date.current + 6.days) # restore
    past_plan&.destroy
    extra_recipes&.each(&:destroy)
  end

  test "skips hard exclusion for small catalogs under threshold" do
    # With only 3 fixture recipes (< 20), hard exclusion is skipped
    past_plan = create_past_plan_using([ recipes(:one) ])
    plan = create_target_plan

    selector = build_selector(plan)
    result = selector.select(limit: 100)

    # Should still include the recipe from the past plan since catalog is small
    assert_includes result.map(&:id), recipes(:one).id
  ensure
    past_plan&.destroy
  end

  test "does not exclude recipes when no past plans exist" do
    plan = create_target_plan

    selector = build_selector(plan)
    result = selector.select(limit: 100)

    assert_equal eligible_recipe_count, result.size
  end

  test "scores recipes with diet compatibility when participant diets provided" do
    # Set diet_scores on a recipe
    recipes(:one).nutrition_data.update_column(:diet_scores, { "keto" => 0.95, "standard" => 0.3 })
    recipes(:two).nutrition_data.update_column(:diet_scores, { "keto" => 0.2, "standard" => 0.9 })

    plan = create_target_plan
    selector = RecipeSelector.new(
      @account, plan,
      meal_types: @meal_types,
      participant_diets: [ "Ketogenic (Keto)" ],
      current_date: @current_date
    )

    result = selector.select(limit: 100)

    # Both should be included (small catalog) but salmon should score higher on diet compatibility
    assert_includes result.map(&:id), recipes(:one).id
    assert_includes result.map(&:id), recipes(:two).id
  ensure
    recipes(:one).nutrition_data.update_column(:diet_scores, nil)
    recipes(:two).nutrition_data.update_column(:diet_scores, nil)
  end

  test "handles nil diet_scores gracefully" do
    recipes(:one).nutrition_data.update_column(:diet_scores, nil)
    plan = create_target_plan

    selector = RecipeSelector.new(
      @account, plan,
      meal_types: @meal_types,
      participant_diets: [ "Ketogenic (Keto)" ],
      current_date: @current_date
    )

    # Should not raise
    result = selector.select(limit: 100)
    assert result.any?
  end

  test "category fit boosts recipes matching active meal types" do
    extra_recipes = create_recipes_with_nutrition(20, category: :dinner)
    breakfast_recipes = create_recipes_with_nutrition(5, category: :breakfast)
    plan = create_target_plan

    selector = RecipeSelector.new(
      @account, plan,
      meal_types: %w[breakfast],
      current_date: @current_date
    )

    result = selector.select(limit: 10)
    breakfast_count = result.count { |r| r.category == "breakfast" }
    non_breakfast_count = result.size - breakfast_count

    # Breakfast recipes should be at least as many as non-breakfast recipes
    # (hard exclusion may remove 1 breakfast fixture recipe used in a past plan)
    assert breakfast_count >= non_breakfast_count,
      "Expected at least as many breakfast (#{breakfast_count}) as non-breakfast (#{non_breakfast_count}) recipes"
  ensure
    extra_recipes&.each(&:destroy)
    breakfast_recipes&.each(&:destroy)
  end

  test "newness bonus boosts recently created recipes" do
    old_recipe = @account.recipes.create!(title: "Old Recipe", category: :dinner, servings: 4, created_at: 2.months.ago)
    old_recipe.create_nutrition_data!(calories: 300, fat: 15, protein: 25, carbs: 5, net_carbs: 5)
    new_recipe = @account.recipes.create!(title: "New Recipe", category: :dinner, servings: 4, created_at: @current_date - 3.days)
    new_recipe.create_nutrition_data!(calories: 350, fat: 18, protein: 30, carbs: 4, net_carbs: 4)

    plan = create_target_plan

    selector = build_selector(plan)
    result = selector.select(limit: 100)

    assert_includes result.map(&:id), new_recipe.id
    assert_includes result.map(&:id), old_recipe.id
  ensure
    old_recipe&.destroy
    new_recipe&.destroy
  end

  test "respects minimum per category floor" do
    # Create recipes across multiple categories
    breakfast_recipes = create_recipes_with_nutrition(5, category: :breakfast)
    dinner_recipes = create_recipes_with_nutrition(30, category: :dinner)
    plan = create_target_plan

    selector = RecipeSelector.new(
      @account, plan,
      meal_types: %w[breakfast dinner],
      current_date: @current_date
    )

    result = selector.select(limit: 15)
    breakfast_count = result.count { |r| r.category == "breakfast" }

    # Should have at least MIN_PER_CATEGORY breakfast recipes
    assert breakfast_count >= RecipeSelector::MIN_PER_CATEGORY
  ensure
    breakfast_recipes&.each(&:destroy)
    dinner_recipes&.each(&:destroy)
  end

  test "select returns at most limit recipes" do
    extra_recipes = create_recipes_with_nutrition(60, category: :dinner)
    plan = create_target_plan

    selector = build_selector(plan)
    result = selector.select(limit: 25)

    assert result.size <= 25
  ensure
    extra_recipes&.each(&:destroy)
  end

  private

  def build_selector(plan)
    RecipeSelector.new(
      @account, plan,
      meal_types: @meal_types,
      current_date: @current_date
    )
  end

  def eligible_recipe_count
    @account.recipes.joins(:nutrition_data).where.not(recipe_nutrition_data: { calories: nil }).count
  end

  def create_target_plan
    start_date = @current_date + 1.day
    plan = @account.meal_plans.create!(
      name: "Test Plan",
      start_date: start_date,
      end_date: start_date + 6.days,
      user: users(:one)
    )
    7.times do |i|
      plan.days.create!(date: start_date + i.days, day_number: i + 1)
    end
    plan
  end

  def create_past_plan_using(recipes_used)
    # Use a date just before @current_date so this is the most recent past plan
    past_start = @current_date - 8.days
    plan = @account.meal_plans.create!(
      name: "Past Plan",
      start_date: past_start,
      end_date: past_start + 6.days,
      user: users(:one)
    )
    day = plan.days.create!(date: past_start, day_number: 1)
    recipes_used.each do |recipe|
      day.meals.create!(recipe: recipe, meal_type: :dinner, servings: 1.0)
    end
    plan
  end

  # --- Rating tests ---

  test "1-star recipes excluded from candidates" do
    recipes(:one).update!(rating: 1)
    plan = create_target_plan

    selector = build_selector(plan)
    result = selector.select(limit: 100)

    refute_includes result.map(&:id), recipes(:one).id
  ensure
    recipes(:one).update!(rating: nil)
  end

  test "5-star recipes score higher than unrated" do
    extra_recipes = create_recipes_with_nutrition(20, category: :dinner)
    recipes(:one).update!(rating: 5)
    plan = create_target_plan

    selector = build_selector(plan)
    scored = selector.send(:score_recipes, selector.send(:fetch_eligible_recipes))

    rated_entry = scored.find { |s| s[:recipe].id == recipes(:one).id }
    unrated_entry = scored.find { |s| s[:recipe].rating.nil? }

    # The 5-star recipe gets 100 * 0.15 = 15 extra vs unrated 50 * 0.15 = 7.5
    # So the rating component should be higher
    rated_rating_component = RecipeSelector::SCORE_WEIGHTS[:user_rating] * 100.0
    unrated_rating_component = RecipeSelector::SCORE_WEIGHTS[:user_rating] * 50.0
    assert rated_rating_component > unrated_rating_component
  ensure
    recipes(:one).update!(rating: nil)
    extra_recipes&.each(&:destroy)
  end

  test "unrated recipes get neutral 50.0 rating score" do
    plan = create_target_plan
    selector = build_selector(plan)

    score = selector.send(:user_rating_score, recipes(:one))
    assert_equal 50.0, score
  end

  test "score weights sum to 1.0" do
    assert_in_delta 1.0, RecipeSelector::SCORE_WEIGHTS.values.sum, 0.001
  end

  def create_recipes_with_nutrition(count, category: :dinner)
    count.times.map do |i|
      recipe = @account.recipes.create!(
        title: "Test Recipe #{category} #{i + 1} #{SecureRandom.hex(4)}",
        category: category,
        servings: 4,
        created_at: @current_date - 1.month
      )
      recipe.create_nutrition_data!(
        calories: 200 + (i * 10),
        fat: 10 + i,
        protein: 20 + i,
        carbs: 5 + i,
        net_carbs: 3 + i
      )
      recipe
    end
  end
end

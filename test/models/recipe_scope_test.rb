require "test_helper"

class RecipeScopeTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @salmon = recipes(:one)    # dinner, prep 15, cook 12, 450 cal
    @eggs = recipes(:two)      # breakfast, prep 5, cook 10, 320 cal
    @cauliflower = recipes(:side_dish) # sides, prep 10, cook 20, 180 cal
  end

  # --- has_many :meal_plan_meals ---

  test "recipe has_many meal_plan_meals" do
    assert_respond_to @salmon, :meal_plan_meals
    assert_includes @salmon.meal_plan_meals, meal_plan_meals(:dinner)
  end

  # --- by_search ---

  test "by_search matches title" do
    results = @account.recipes.by_search("salmon")
    assert_includes results, @salmon
    assert_not_includes results, @eggs
  end

  test "by_search matches description" do
    results = @account.recipes.by_search("keto-friendly")
    assert_includes results, @salmon
  end

  test "by_search matches ingredient name" do
    @salmon.ingredients.create!(name: "garlic butter")
    results = @account.recipes.by_search("garlic")
    assert_includes results, @salmon
  end

  test "by_search returns nothing for gibberish" do
    results = @account.recipes.by_search("xyzzyplugh")
    assert_empty results
  end

  test "by_search with nil returns all" do
    results = @account.recipes.by_search(nil)
    assert_equal @account.recipes.count, results.count
  end

  # --- by_cook_time ---

  test "by_cook_time filters by total time" do
    # salmon: 15+12=27, eggs: 5+10=15, cauliflower: 10+20=30
    results = @account.recipes.by_cook_time(20)
    assert_includes results, @eggs
    assert_not_includes results, @salmon
    assert_not_includes results, @cauliflower
  end

  test "by_cook_time with nil returns all" do
    results = @account.recipes.by_cook_time(nil)
    assert_equal @account.recipes.count, results.count
  end

  # --- by_calorie_range ---

  test "by_calorie_range filters minimum" do
    results = @account.recipes.by_calorie_range(300, nil)
    assert_includes results, @salmon   # 450
    assert_includes results, @eggs     # 320
    assert_not_includes results, @cauliflower # 180
  end

  test "by_calorie_range filters maximum" do
    results = @account.recipes.by_calorie_range(nil, 350)
    assert_not_includes results, @salmon  # 450
    assert_includes results, @eggs        # 320
    assert_includes results, @cauliflower # 180
  end

  test "by_calorie_range filters both" do
    results = @account.recipes.by_calorie_range(200, 400)
    assert_includes results, @eggs        # 320
    assert_not_includes results, @salmon  # 450
    assert_not_includes results, @cauliflower # 180
  end

  # --- sorted_by ---

  test "sorted_by newest returns newest first" do
    results = @account.recipes.sorted_by("newest")
    assert_equal results.first, @account.recipes.order(created_at: :desc).first
  end

  test "sorted_by alphabetical orders by title" do
    results = @account.recipes.sorted_by("alphabetical").to_a
    titles = results.map(&:title)
    assert_equal titles, titles.sort
  end

  test "sorted_by quickest orders by total time ascending" do
    results = @account.recipes.sorted_by("quickest").to_a
    times = results.map(&:total_time)
    assert_equal times, times.sort
  end

  test "sorted_by most_used orders by meal plan usage" do
    # salmon has 1 meal_plan_meal (dinner), eggs has 1 (breakfast), cauliflower has 0
    results = @account.recipes.sorted_by("most_used").to_a
    assert_equal @cauliflower, results.last
  end

  test "sorted_by defaults to newest for unknown values" do
    results = @account.recipes.sorted_by("bogus")
    assert_equal results.first, @account.recipes.order(created_at: :desc).first
  end
end

require "test_helper"

class FakeAiClient
  def initialize(response)
    @response = response
  end

  def chat_with_tools(**_kwargs)
    @response
  end
end

class MealPlanGeneratorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @user = users(:one)
    @meal_plan = create_test_meal_plan
  end

  test "generates meal plan with valid recipes" do
    ai_client = fake_client(build_ai_response(@meal_plan))
    generator = MealPlanGenerator.new(@meal_plan, ai_client: ai_client)

    result = generator.generate

    assert result[:meals_assigned] > 0
    assert_equal @meal_plan.days.count, result[:days_planned]
    assert @meal_plan.days.reload.flat_map { |d| d.meals.to_a }.any?
  end

  test "raises error when not enough recipes with nutrition data" do
    RecipeNutritionData.where(recipe_id: @account.recipes.pluck(:id)).delete_all

    ai_client = fake_client({})
    generator = MealPlanGenerator.new(@meal_plan, ai_client: ai_client)

    error = assert_raises(MealPlanGenerator::GenerationError) { generator.generate }
    assert_match(/Not enough recipes/, error.message)
  end

  test "filters only recipes with nutrition data" do
    no_nutrition = @account.recipes.create!(title: "No Nutrition Recipe", category: :dinner)

    ai_client = fake_client(build_ai_response(@meal_plan))
    generator = MealPlanGenerator.new(@meal_plan, ai_client: ai_client)

    result = generator.generate
    assert result[:meals_assigned] > 0

    no_nutrition.destroy
  end

  test "applies preferences to constraints" do
    ai_client = fake_client(build_ai_response(@meal_plan, meal_types: %w[lunch dinner snack]))
    generator = MealPlanGenerator.new(
      @meal_plan,
      preferences: %w[skip_breakfast no_repeats],
      ai_client: ai_client
    )

    result = generator.generate
    assert_includes result[:preferences_applied], "skip_breakfast"
    assert_includes result[:preferences_applied], "no_repeats"
  end

  test "passes special requests through" do
    ai_client = fake_client(build_ai_response(@meal_plan))
    generator = MealPlanGenerator.new(
      @meal_plan,
      special_requests: "Include chicken at least twice",
      ai_client: ai_client
    )

    result = generator.generate
    assert_equal "Include chicken at least twice", result[:special_requests]
  end

  test "calculates portions for participants" do
    dad = dietary_profiles(:dad)
    @meal_plan.participants.create!(dietary_profile: dad)

    ai_client = fake_client(build_ai_response(@meal_plan))
    generator = MealPlanGenerator.new(@meal_plan, ai_client: ai_client)

    generator.generate

    participant = @meal_plan.participants.first
    assert participant.portions.any?, "Expected portions to be calculated for participant"
  end

  test "skips unknown recipe ids from AI response" do
    # AI now returns integer indices; 999 is an invalid index not in the mapping
    response = {
      days: [
        {
          day_number: 1,
          meals: [
            { meal_type: "breakfast", recipe_id: 999 },
            { meal_type: "dinner", recipe_id: 1 }
          ]
        }
      ]
    }

    ai_client = fake_client(response)
    generator = MealPlanGenerator.new(@meal_plan, ai_client: ai_client)

    generator.generate
    day_one = @meal_plan.days.find_by(day_number: 1)
    assert_equal 1, day_one.meals.count
  end

  test "assigns default servings of 1.0 for all meals" do
    # Servings are no longer returned by AI — hardcoded to 1.0
    response = {
      days: [
        {
          day_number: 1,
          meals: [
            { meal_type: "dinner", recipe_id: 1 }
          ]
        }
      ]
    }

    ai_client = fake_client(response)
    generator = MealPlanGenerator.new(@meal_plan, ai_client: ai_client)

    generator.generate

    meal = @meal_plan.days.find_by(day_number: 1).meals.first
    assert_equal 1.0, meal.servings.to_f
  end

  test "reports progress via callback" do
    ai_client = fake_client(build_ai_response(@meal_plan))
    generator = MealPlanGenerator.new(@meal_plan, ai_client: ai_client)

    progress_values = []
    generator.generate { |pct| progress_values << pct }

    assert progress_values.any?
    assert progress_values.all? { |p| p >= 0 && p <= 100 }
  end

  test "raises on unexpected tool name" do
    bad_client = FakeAiClient.new({ name: "wrong_tool", input: {} })
    generator = MealPlanGenerator.new(@meal_plan, ai_client: bad_client)

    assert_raises(MealPlanGenerator::GenerationError) { generator.generate }
  end

  private

  def create_test_meal_plan
    start_date = 3.months.from_now.to_date
    plan = @account.meal_plans.create!(
      user: @user,
      name: "AI Test Plan",
      start_date: start_date,
      end_date: start_date + 6.days
    )

    7.times do |i|
      plan.days.create!(date: start_date + i.days, day_number: i + 1)
    end

    plan
  end

  def fake_client(ai_response)
    FakeAiClient.new({ name: "assign_meals", input: ai_response })
  end

  def build_ai_response(plan, meal_types: %w[breakfast lunch dinner snack])
    # AI now returns integer indices (1-based) instead of UUIDs.
    # RecipeSelector returns eligible recipes; indices 1 and 2 map to the first two.
    recipe_indices = [ 1, 2 ]

    # Use symbol keys to match real Anthropic gem behavior (tool_block.input.to_h returns symbols)
    {
      days: plan.days.order(:day_number).map do |day|
        {
          day_number: day.day_number,
          meals: meal_types.map do |mt|
            { meal_type: mt, recipe_id: recipe_indices.sample }
          end
        }
      end
    }
  end
end

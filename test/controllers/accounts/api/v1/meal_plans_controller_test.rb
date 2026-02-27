require "test_helper"

class Accounts::Api::V1::MealPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @user = users(:one)
    @recipe = recipes(:one)
    @read_token = identity_access_tokens(:read_token)
    @write_token = identity_access_tokens(:write_token)

    @nutrition = recipe_nutrition_data(:salmon_nutrition)
  end

  def auth_header(token)
    { "Authorization" => "Bearer #{token.token}" }
  end

  test "should list meal plans" do
    meal_plan = MealPlan.create!(
      account: @account,
      user: @user,
      name: "Test Plan",
      start_date: Date.today,
      end_date: Date.today + 6.days
    )

    get "/#{@account.external_account_id}/api/v1/meal_plans",
        headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)

    assert_includes json.keys, "meal_plans"
    plan_data = json["meal_plans"].find { |p| p["id"] == meal_plan.id }
    assert_not_nil plan_data
    assert_equal "Test Plan", plan_data["name"]
    assert_equal 7, plan_data["duration_days"]
  end

  test "should show meal plan with days and meals" do
    meal_plan = create_meal_plan_with_meals

    get "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan.id}",
        headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal meal_plan.id, json["meal_plan"]["id"]
    assert_includes json["meal_plan"].keys, "days"
    assert json["meal_plan"]["days"].any?

    day = json["meal_plan"]["days"].first
    assert_includes day.keys, "meals"
    assert_includes day.keys, "totals"
    assert_includes day["totals"].keys, "calories"
  end

  test "should create meal plan with nested attributes" do
    meal_plan_params = {
      meal_plan: {
        name: "New Week Plan",
        start_date: Date.today,
        end_date: Date.today + 6.days,
        daily_calories_target: 1800,
        days_attributes: [
          {
            day_number: 1,
            date: Date.today,
            meals_attributes: [
              { recipe_id: @recipe.id, meal_type: "breakfast", servings: 1 },
              { recipe_id: @recipe.id, meal_type: "dinner", servings: 1.5 }
            ]
          }
        ]
      }
    }

    assert_difference "MealPlan.count" do
      post "/#{@account.external_account_id}/api/v1/meal_plans",
           params: meal_plan_params,
           headers: auth_header(@write_token),
           as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)

    assert_equal "New Week Plan", json["meal_plan"]["name"]
    assert_equal 1800, json["meal_plan"]["daily_calories_target"]
    assert_equal 1, json["meal_plan"]["days"].length
    assert_equal 2, json["meal_plan"]["days"].first["meals"].length
  end

  test "should reject create without write permission" do
    meal_plan_params = {
      meal_plan: {
        name: "Test Plan",
        start_date: Date.today,
        end_date: Date.today + 6.days
      }
    }

    assert_no_difference "MealPlan.count" do
      post "/#{@account.external_account_id}/api/v1/meal_plans",
           params: meal_plan_params,
           headers: auth_header(@read_token),
           as: :json
    end

    assert_response :forbidden
  end

  test "should update meal plan" do
    meal_plan = MealPlan.create!(
      account: @account,
      user: @user,
      name: "Original Name",
      start_date: Date.today,
      end_date: Date.today + 6.days
    )

    patch "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan.id}",
          params: { meal_plan: { name: "Updated Name" } },
          headers: auth_header(@write_token),
          as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Updated Name", json["meal_plan"]["name"]
  end

  test "should delete meal plan" do
    meal_plan = MealPlan.create!(
      account: @account,
      user: @user,
      name: "To Delete",
      start_date: Date.today,
      end_date: Date.today + 6.days
    )

    assert_difference "MealPlan.count", -1 do
      delete "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan.id}",
             headers: auth_header(@write_token)
    end

    assert_response :no_content
  end

  test "should return validation errors" do
    post "/#{@account.external_account_id}/api/v1/meal_plans",
         params: { meal_plan: { name: "Missing Dates" } },
         headers: auth_header(@write_token),
         as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["errors"].any?
  end

  # ===========================================================================
  # POST generate
  # ===========================================================================

  test "generate requires authentication" do
    post "/#{@account.external_account_id}/api/v1/meal_plans/generate"
    assert_response :unauthorized
  end

  test "generate requires write permission" do
    post "/#{@account.external_account_id}/api/v1/meal_plans/generate",
         params: { meal_plan: { name: "AI Plan", start_date: Date.today, end_date: Date.today + 6.days } },
         headers: auth_header(@read_token),
         as: :json
    assert_response :forbidden
  end

  test "generate creates plan and enqueues job" do
    assert_difference [ "MealPlan.count", "AiTaskStatus.count" ] do
      assert_enqueued_with(job: MealPlanGenerationJob) do
        post "/#{@account.external_account_id}/api/v1/meal_plans/generate",
             params: {
               meal_plan: {
                 name: "AI Generated Plan",
                 start_date: Date.today,
                 end_date: Date.today + 6.days,
                 daily_calories_target: 2000
               },
               preferences: [ "no_repeats", "high_variety" ],
               special_requests: "Extra protein"
             },
             headers: auth_header(@write_token),
             as: :json
      end
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert json["task_id"].present?
    assert json["meal_plan_id"].present?
    assert_equal "pending", json["status"]

    # Verify days were generated
    plan = MealPlan.find(json["meal_plan_id"])
    assert_equal 7, plan.days.count
  end

  test "generate returns validation errors for invalid plan" do
    assert_no_difference "MealPlan.count" do
      post "/#{@account.external_account_id}/api/v1/meal_plans/generate",
           params: { meal_plan: { name: "Missing Dates" } },
           headers: auth_header(@write_token),
           as: :json
    end

    assert_response :unprocessable_entity
  end

  # ===========================================================================
  # GET generate_status
  # ===========================================================================

  test "generate_status requires authentication" do
    task = @account.ai_task_statuses.create!(task_type: "meal_plan_generation")
    get "/#{@account.external_account_id}/api/v1/meal_plans/generate_status/#{task.id}"
    assert_response :unauthorized
  end

  test "generate_status returns pending task" do
    task = @account.ai_task_statuses.create!(task_type: "meal_plan_generation")

    get "/#{@account.external_account_id}/api/v1/meal_plans/generate_status/#{task.id}",
        headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "pending", json["status"]
    assert_equal 0, json["progress_percentage"]
  end

  test "generate_status returns 404 for nonexistent task" do
    get "/#{@account.external_account_id}/api/v1/meal_plans/generate_status/nonexistent",
        headers: auth_header(@read_token)
    assert_response :not_found
  end

  # ===========================================================================
  # POST swap_meal
  # ===========================================================================

  test "swap_meal requires authentication" do
    meal_plan = create_meal_plan_with_meals
    post "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan.id}/swap_meal"
    assert_response :unauthorized
  end

  test "swap_meal requires write permission" do
    meal_plan = create_meal_plan_with_meals
    post "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan.id}/swap_meal",
         params: { meal_id: "x", recipe_id: "y" },
         headers: auth_header(@read_token),
         as: :json
    assert_response :forbidden
  end

  test "swap_meal returns 400 when params missing" do
    meal_plan = create_meal_plan_with_meals
    post "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan.id}/swap_meal",
         headers: auth_header(@write_token),
         as: :json
    assert_response :bad_request
  end

  test "swap_meal swaps the recipe on a meal" do
    meal_plan = create_meal_plan_with_meals
    meal = meal_plan.days.first.meals.first
    new_recipe = recipes(:two)

    post "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan.id}/swap_meal",
         params: { meal_id: meal.id, recipe_id: new_recipe.id },
         headers: auth_header(@write_token),
         as: :json

    assert_response :success
    assert_equal new_recipe.id, meal.reload.recipe_id
  end

  test "swap_meal returns 404 for meal not in plan" do
    meal_plan = create_meal_plan_with_meals
    other_plan = create_meal_plan_with_meals
    other_meal = other_plan.days.first.meals.first

    post "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan.id}/swap_meal",
         params: { meal_id: other_meal.id, recipe_id: @recipe.id },
         headers: auth_header(@write_token),
         as: :json

    assert_response :not_found
  end

  test "swap_meal returns 404 for nonexistent recipe" do
    meal_plan = create_meal_plan_with_meals
    meal = meal_plan.days.first.meals.first

    post "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan.id}/swap_meal",
         params: { meal_id: meal.id, recipe_id: "nonexistent" },
         headers: auth_header(@write_token),
         as: :json

    assert_response :not_found
  end

  # ===========================================================================
  # POST regenerate_day
  # ===========================================================================

  test "regenerate_day requires authentication" do
    meal_plan = create_meal_plan_with_meals
    post "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan.id}/regenerate_day"
    assert_response :unauthorized
  end

  test "regenerate_day requires write permission" do
    meal_plan = create_meal_plan_with_meals
    post "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan.id}/regenerate_day",
         params: { day_number: 1 },
         headers: auth_header(@read_token),
         as: :json
    assert_response :forbidden
  end

  test "regenerate_day returns 404 for invalid day number" do
    meal_plan = create_meal_plan_with_meals
    post "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan.id}/regenerate_day",
         params: { day_number: 99 },
         headers: auth_header(@write_token),
         as: :json
    assert_response :not_found
  end

  test "regenerate_day clears meals and calls generator" do
    meal_plan = create_meal_plan_with_meals
    day = meal_plan.days.first
    original_meal_count = day.meals.count
    assert original_meal_count > 0

    # Temporarily override MealPlanGenerator.new to return a fake
    original_new = MealPlanGenerator.method(:new)
    fake = Object.new
    fake.define_singleton_method(:generate) { |&_block| { meals_assigned: 0, days_planned: 1 } }

    MealPlanGenerator.define_singleton_method(:new) { |*_args, **_kwargs| fake }

    post "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan.id}/regenerate_day",
         params: { day_number: 1 },
         headers: auth_header(@write_token),
         as: :json

    assert_response :success
  ensure
    MealPlanGenerator.define_singleton_method(:new, original_new)
  end

  test "regenerate_day returns error when generator fails" do
    meal_plan = create_meal_plan_with_meals

    original_new = MealPlanGenerator.method(:new)
    fake = Object.new
    fake.define_singleton_method(:generate) { |&_block| raise MealPlanGenerator::GenerationError, "Not enough recipes" }

    MealPlanGenerator.define_singleton_method(:new) { |*_args, **_kwargs| fake }

    post "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan.id}/regenerate_day",
         params: { day_number: 1 },
         headers: auth_header(@write_token),
         as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "Not enough recipes", json["error"]
  ensure
    MealPlanGenerator.define_singleton_method(:new, original_new)
  end

  test "should calculate daily totals correctly" do
    meal_plan = create_meal_plan_with_meals

    get "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan.id}",
        headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)

    day = json["meal_plan"]["days"].first
    # 2 meals with recipe having 450 calories each at 1 serving
    assert_equal 900, day["totals"]["calories"]
  end

  private

  def create_meal_plan_with_meals
    meal_plan = MealPlan.create!(
      account: @account,
      user: @user,
      name: "Test Plan",
      start_date: Date.today,
      end_date: Date.today + 6.days
    )

    day = meal_plan.days.create!(
      day_number: 1,
      date: Date.today
    )

    day.meals.create!(recipe: @recipe, meal_type: :breakfast, servings: 1)
    day.meals.create!(recipe: @recipe, meal_type: :dinner, servings: 1)

    meal_plan
  end
end

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

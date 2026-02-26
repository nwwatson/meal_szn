require "test_helper"

class Accounts::Api::V1::MealPlanning::RecipesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @recipe = recipes(:one)
    @read_token = identity_access_tokens(:read_token)
  end

  def auth_header(token)
    { "Authorization" => "Bearer #{token.token}" }
  end

  test "should list recipes with nutrition data for meal planning" do
    get "/#{@account.external_account_id}/api/v1/meal_planning/recipes",
        headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)

    assert_includes json.keys, "recipes"
    assert_includes json.keys, "meta"

    assert_includes json["meta"].keys, "categories"
    assert_includes json["meta"].keys, "nutrition_summary"

    recipe_data = json["recipes"].find { |r| r["id"] == @recipe.id }
    assert_not_nil recipe_data
    assert_includes recipe_data.keys, "nutrition_per_serving"
  end

  test "should filter recipes by category" do
    get "/#{@account.external_account_id}/api/v1/meal_planning/recipes",
        params: { category: "dinner" },
        headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)

    json["recipes"].each do |recipe|
      assert_equal "dinner", recipe["category"]
    end
  end

  test "should show single recipe with full details" do
    get "/#{@account.external_account_id}/api/v1/meal_planning/recipes/#{@recipe.id}",
        headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal @recipe.id, json["recipe"]["id"]
    assert_includes json["recipe"].keys, "nutrition_per_serving"
    assert_equal 450, json["recipe"]["nutrition_per_serving"]["calories"]
  end

  test "should return 404 for non-existent recipe" do
    get "/#{@account.external_account_id}/api/v1/meal_planning/recipes/nonexistent",
        headers: auth_header(@read_token)

    assert_response :not_found
  end

  test "meal planning response includes essential fields only" do
    get "/#{@account.external_account_id}/api/v1/meal_planning/recipes",
        headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)

    recipe_data = json["recipes"].find { |r| r["id"] == @recipe.id }
    assert_includes recipe_data.keys, "title"
    assert_includes recipe_data.keys, "category"
    assert_includes recipe_data.keys, "servings"
    assert_includes recipe_data.keys, "tags"
    # Trimmed fields should not be present (reduces AI token costs)
    assert_nil recipe_data["url"]
    assert_nil recipe_data["ingredients_summary"]
  end
end

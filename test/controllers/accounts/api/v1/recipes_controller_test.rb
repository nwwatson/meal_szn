require "test_helper"

class Accounts::Api::V1::RecipesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @recipe = recipes(:one)
    @read_token = identity_access_tokens(:read_token)
    @write_token = identity_access_tokens(:write_token)
  end

  def auth_header(token)
    { "Authorization" => "Bearer #{token.token}" }
  end

  test "should require authentication" do
    get "/#{@account.external_account_id}/api/v1/recipes"
    assert_response :unauthorized
  end

  test "should list recipes with read token" do
    get "/#{@account.external_account_id}/api/v1/recipes",
        headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_includes json.keys, "recipes"
    assert_includes json.keys, "meta"
  end

  test "should filter recipes by category" do
    get "/#{@account.external_account_id}/api/v1/recipes",
        params: { category: "dinner" },
        headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)
    json["recipes"].each do |recipe|
      assert_equal "dinner", recipe["category"]
    end
  end

  test "should show single recipe" do
    get "/#{@account.external_account_id}/api/v1/recipes/#{@recipe.id}",
        headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @recipe.id, json["recipe"]["id"]
    assert_equal @recipe.title, json["recipe"]["title"]
  end

  test "should return 404 for non-existent recipe" do
    get "/#{@account.external_account_id}/api/v1/recipes/nonexistent",
        headers: auth_header(@read_token)

    assert_response :not_found
  end

  test "should create recipe with write token" do
    recipe_params = {
      recipe: {
        title: "New Test Recipe",
        category: "dinner",
        description: "A test recipe",
        servings: 4,
        prep_time: 15,
        cook_time: 30,
        ingredients_attributes: [
          { name: "Chicken", quantity: "1", unit: "lb" },
          { name: "Butter", quantity: "2", unit: "tbsp" }
        ],
        instructions_attributes: [
          { step_number: 1, instruction: "Preheat oven" },
          { step_number: 2, instruction: "Cook chicken" }
        ],
        nutrition_data_attributes: {
          calories: 350,
          fat: 20,
          protein: 30,
          carbs: 5,
          fiber: 1
        }
      }
    }

    assert_difference "Recipe.count" do
      post "/#{@account.external_account_id}/api/v1/recipes",
           params: recipe_params,
           headers: auth_header(@write_token),
           as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "New Test Recipe", json["recipe"]["title"]
    assert_equal 2, json["recipe"]["ingredients"].length
    assert_equal 2, json["recipe"]["instructions"].length
  end

  test "should reject create with read-only token" do
    recipe_params = {
      recipe: {
        title: "Test Recipe",
        category: "dinner"
      }
    }

    assert_no_difference "Recipe.count" do
      post "/#{@account.external_account_id}/api/v1/recipes",
           params: recipe_params,
           headers: auth_header(@read_token),
           as: :json
    end

    assert_response :forbidden
  end

  test "should update recipe with write token" do
    patch "/#{@account.external_account_id}/api/v1/recipes/#{@recipe.id}",
          params: { recipe: { title: "Updated Title" } },
          headers: auth_header(@write_token),
          as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Updated Title", json["recipe"]["title"]
  end

  test "should reject update with read-only token" do
    patch "/#{@account.external_account_id}/api/v1/recipes/#{@recipe.id}",
          params: { recipe: { title: "Updated Title" } },
          headers: auth_header(@read_token),
          as: :json

    assert_response :forbidden
  end

  test "should delete recipe with write token" do
    # Use side_dish recipe which has no meal plan references
    recipe = recipes(:side_dish)
    assert_difference "Recipe.count", -1 do
      delete "/#{@account.external_account_id}/api/v1/recipes/#{recipe.id}",
             headers: auth_header(@write_token)
    end

    assert_response :no_content
  end

  test "should reject delete with read-only token" do
    assert_no_difference "Recipe.count" do
      delete "/#{@account.external_account_id}/api/v1/recipes/#{@recipe.id}",
             headers: auth_header(@read_token)
    end

    assert_response :forbidden
  end

  test "should return validation errors for invalid recipe" do
    post "/#{@account.external_account_id}/api/v1/recipes",
         params: { recipe: { title: "" } },
         headers: auth_header(@write_token),
         as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["errors"], "Title can't be blank"
  end

  test "calculate_nutrition returns nutrition for recipe with resolved ingredients" do
    recipe = @account.recipes.create!(title: "Calc Test", category: :breakfast, servings: 2)
    egg_item = nutrition_items(:egg)
    recipe.ingredients.create!(name: "Eggs", quantity: "4", unit: "large", nutrition_item: egg_item, display_order: 0)

    post "/#{@account.external_account_id}/api/v1/recipes/#{recipe.id}/calculate_nutrition",
         headers: auth_header(@write_token),
         as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert json["recipe"]["nutrition"].present?
    assert json["recipe"]["nutrition"]["calories"] > 0
  end

  test "calculate_nutrition returns error for recipe with no ingredients" do
    recipe = @account.recipes.create!(title: "Empty", category: :dinner)

    post "/#{@account.external_account_id}/api/v1/recipes/#{recipe.id}/calculate_nutrition",
         headers: auth_header(@write_token),
         as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "Recipe has no ingredients", json["error"]
  end

  test "calculate_nutrition returns unresolved ingredients" do
    @recipe.ingredients.create!(name: "Unknown exotic thing", quantity: "1", unit: "cup", display_order: 0)

    post "/#{@account.external_account_id}/api/v1/recipes/#{@recipe.id}/calculate_nutrition",
         headers: auth_header(@write_token),
         as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["unresolved_ingredients"].present?
  end

  test "calculate_nutrition requires write permission" do
    post "/#{@account.external_account_id}/api/v1/recipes/#{@recipe.id}/calculate_nutrition",
         headers: auth_header(@read_token),
         as: :json

    assert_response :forbidden
  end
end

require "test_helper"

class Accounts::RecipesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
    @recipe = recipes(:one)
  end

  def account_path_prefix
    "/#{@account.external_account_id}"
  end

  test "should redirect to sign in when unauthenticated" do
    get "#{account_path_prefix}/recipes"
    assert_response :redirect
  end

  test "should list recipes" do
    sign_in_as(@session)
    get "#{account_path_prefix}/recipes"
    assert_response :success
    assert_select "h1", "Recipes"
  end

  test "should filter recipes by category" do
    sign_in_as(@session)
    get "#{account_path_prefix}/recipes", params: { category: "dinner" }
    assert_response :success
  end

  test "should show recipe" do
    sign_in_as(@session)
    get "#{account_path_prefix}/recipes/#{@recipe.id}"
    assert_response :success
    assert_select "h1", @recipe.title
  end

  test "should get new recipe form" do
    sign_in_as(@session)
    get "#{account_path_prefix}/recipes/new"
    assert_response :success
    assert_select "h1", "New Recipe"
  end

  test "should create recipe" do
    sign_in_as(@session)

    assert_difference "Recipe.count" do
      post "#{account_path_prefix}/recipes", params: {
        recipe: {
          title: "New Test Recipe",
          category: "dinner",
          description: "A test recipe",
          servings: 4,
          prep_time: 15,
          cook_time: 30,
          ingredients_attributes: [
            { name: "Chicken", quantity: "1", unit: "lb" }
          ],
          instructions_attributes: [
            { step_number: 1, instruction: "Cook it" }
          ]
        }
      }
    end

    assert_response :redirect
    new_recipe = Recipe.order(created_at: :desc).first
    assert_equal "New Test Recipe", new_recipe.title
  end

  test "should reject invalid recipe" do
    sign_in_as(@session)

    assert_no_difference "Recipe.count" do
      post "#{account_path_prefix}/recipes", params: {
        recipe: { title: "", category: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit form" do
    sign_in_as(@session)
    get "#{account_path_prefix}/recipes/#{@recipe.id}/edit"
    assert_response :success
    assert_select "h1", "Edit Recipe"
  end

  test "should update recipe" do
    sign_in_as(@session)
    patch "#{account_path_prefix}/recipes/#{@recipe.id}", params: {
      recipe: { title: "Updated Title" }
    }

    assert_response :redirect
    assert_equal "Updated Title", @recipe.reload.title
  end

  test "should delete recipe without meal plan references" do
    sign_in_as(@session)
    recipe = recipes(:side_dish)

    assert_difference "Recipe.count", -1 do
      delete "#{account_path_prefix}/recipes/#{recipe.id}"
    end

    assert_response :redirect
  end

  test "should return 404 for nonexistent recipe" do
    sign_in_as(@session)
    get "#{account_path_prefix}/recipes/nonexistent"
    assert_response :not_found
  end

  test "should filter recipes by tag" do
    sign_in_as(@session)
    keto_tag = tags(:keto)
    get "#{account_path_prefix}/recipes", params: { tags: [ keto_tag.id ] }
    assert_response :success
    assert_select "h2", recipes(:one).title
    assert_select "h2", recipes(:two).title
  end

  test "should create recipe with tags" do
    sign_in_as(@session)

    post "#{account_path_prefix}/recipes", params: {
      recipe: {
        title: "Tagged Recipe",
        category: "dinner",
        tag_list: "keto, new-tag"
      }
    }

    assert_response :redirect
    new_recipe = Recipe.order(created_at: :desc).first
    assert_equal 2, new_recipe.tags.count
    assert_includes new_recipe.tags.pluck(:name), "keto"
    assert_includes new_recipe.tags.pluck(:name), "new-tag"
  end

  test "should update recipe tags" do
    sign_in_as(@session)
    patch "#{account_path_prefix}/recipes/#{@recipe.id}", params: {
      recipe: { tag_list: "dinner party" }
    }

    assert_response :redirect
    assert_equal [ "dinner party" ], @recipe.reload.tags.pluck(:name)
  end

  test "should show recipe with tags" do
    sign_in_as(@session)
    get "#{account_path_prefix}/recipes/#{@recipe.id}"
    assert_response :success
    assert_select "a", "keto"
  end

  test "new recipe form contains unit select with optgroup elements" do
    sign_in_as(@session)
    get "#{account_path_prefix}/recipes/new"
    assert_response :success
    assert_select "select[name*='[unit]']"
    assert_select "optgroup[label='Standard']"
    assert_select "optgroup[label='Metric']"
    assert_select "optgroup[label='Universal']"
  end

  test "should create recipe with manual nutrition mode" do
    sign_in_as(@session)

    post "#{account_path_prefix}/recipes", params: {
      recipe: {
        title: "Manual Nutrition Recipe",
        category: "dinner",
        servings: 4,
        nutrition_mode: "manual",
        ingredients_attributes: [
          { name: "Chicken", quantity: "1", unit: "lb" }
        ],
        instructions_attributes: [
          { step_number: 1, instruction: "Cook it" }
        ],
        nutrition_data_attributes: {
          calories: 500, fat: 30, protein: 40, carbs: 5, fiber: 1, sodium: 300
        }
      }
    }

    assert_response :redirect
    new_recipe = Recipe.order(created_at: :desc).first
    assert_equal 500, new_recipe.nutrition_data.calories
    assert_not new_recipe.nutrition_data.auto_calculated?
  end

  test "should create recipe with auto nutrition mode and resolved ingredients" do
    sign_in_as(@session)

    post "#{account_path_prefix}/recipes", params: {
      recipe: {
        title: "Auto Nutrition Recipe",
        category: "breakfast",
        servings: 2,
        nutrition_mode: "auto",
        ingredients_attributes: [
          { name: "Eggs", quantity: "4", unit: "large" },
          { name: "Butter", quantity: "2", unit: "tbsp" }
        ],
        instructions_attributes: [
          { step_number: 1, instruction: "Scramble eggs in butter" }
        ]
      }
    }

    assert_response :redirect
    new_recipe = Recipe.order(created_at: :desc).first
    assert new_recipe.nutrition_data.present?
    assert new_recipe.nutrition_data.auto_calculated?
    assert new_recipe.nutrition_data.calories.present?
  end

  test "should redirect to resolve ingredients when unresolved" do
    sign_in_as(@session)

    post "#{account_path_prefix}/recipes", params: {
      recipe: {
        title: "Unresolved Recipe",
        category: "dinner",
        servings: 4,
        nutrition_mode: "auto",
        ingredients_attributes: [
          { name: "Xyzzy Unknown Food", quantity: "1", unit: "cup" }
        ],
        instructions_attributes: [
          { step_number: 1, instruction: "Cook it" }
        ]
      }
    }

    assert_response :redirect
    new_recipe = Recipe.order(created_at: :desc).first
    assert_redirected_to resolve_ingredients_recipe_path(new_recipe)
  end

  test "should show resolve ingredients page" do
    sign_in_as(@session)
    # Add an unresolved ingredient
    @recipe.ingredients.create!(name: "Mystery Ingredient", quantity: "1", unit: "cup")

    get "#{account_path_prefix}/recipes/#{@recipe.id}/resolve_ingredients"
    assert_response :success
    assert_select "h1", "Match Ingredients"
  end

  test "resolve ingredients redirects when all resolved" do
    sign_in_as(@session)
    # All existing ingredients are unresolved but let's link them
    @recipe.ingredients.update_all(nutrition_item_id: nutrition_items(:egg).id)

    get "#{account_path_prefix}/recipes/#{@recipe.id}/resolve_ingredients"
    assert_response :redirect
  end

  test "new recipe form contains nutrition mode toggle" do
    sign_in_as(@session)
    get "#{account_path_prefix}/recipes/new"
    assert_response :success
    assert_select "select[name='recipe[nutrition_mode]']"
  end
end

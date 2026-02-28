require "test_helper"

class RecipeToolsTest < ActiveSupport::TestCase
  setup do
    @token = identity_access_tokens(:write_token)
    @account = accounts(:one)
    @recipe = recipes(:one)
    set_current_from_token(@token)
  end

  # ===========================================================================
  # list_recipes
  # ===========================================================================

  test "list_recipes returns recipes" do
    tool = ListRecipesTool.new(headers: auth_headers)
    result = tool.call

    assert result[:content].is_a?(Array)
    data = JSON.parse(result[:content].first[:text])
    assert data["recipes"].is_a?(Array)
    assert data["recipes"].any?
  end

  test "list_recipes accepts search query" do
    tool = ListRecipesTool.new(headers: auth_headers)
    result = tool.call(query: @recipe.title)

    data = JSON.parse(result[:content].first[:text])
    titles = data["recipes"].map { |r| r["title"] }
    assert_includes titles, @recipe.title
  end

  test "list_recipes accepts category filter" do
    tool = ListRecipesTool.new(headers: auth_headers)
    result = tool.call(category: @recipe.category)

    data = JSON.parse(result[:content].first[:text])
    assert data["recipes"].all? { |r| r["category"] == @recipe.category }
  end

  test "list_recipes respects limit" do
    tool = ListRecipesTool.new(headers: auth_headers)
    result = tool.call(limit: 1)

    data = JSON.parse(result[:content].first[:text])
    assert_equal 1, data["recipes"].size
  end

  # ===========================================================================
  # get_recipe
  # ===========================================================================

  test "get_recipe returns full recipe details" do
    tool = GetRecipeTool.new(headers: auth_headers)
    result = tool.call(recipe_id: @recipe.id)

    data = JSON.parse(result[:content].first[:text])
    assert_equal @recipe.id, data["recipe"]["id"]
    assert_equal @recipe.title, data["recipe"]["title"]
  end

  test "get_recipe returns error for nonexistent recipe" do
    tool = GetRecipeTool.new(headers: auth_headers)
    result = tool.call(recipe_id: "nonexistent")

    assert result[:isError]
    data = JSON.parse(result[:content].first[:text])
    assert_equal "Recipe not found", data["error"]
  end

  # ===========================================================================
  # create_recipe
  # ===========================================================================

  test "create_recipe creates a new recipe" do
    tool = CreateRecipeTool.new(headers: auth_headers)

    assert_difference "Recipe.count" do
      result = tool.call(
        title: "MCP Test Recipe",
        description: "Created via MCP",
        category: "dinner",
        servings: 4,
        ingredients: [ "2 cups almond flour", "3 eggs" ],
        instructions: [ "Mix dry ingredients", "Add eggs and combine" ],
        calories: 350,
        fat: 28.0,
        protein: 15.0,
        carbs: 5.0,
        fiber: 2.0
      )

      data = JSON.parse(result[:content].first[:text])
      assert_equal "MCP Test Recipe", data["recipe"]["title"]
      assert_not result[:isError]
    end
  end

  test "create_recipe returns errors for invalid data" do
    tool = CreateRecipeTool.new(headers: auth_headers)

    result = tool.call(title: "")

    assert result[:isError]
    data = JSON.parse(result[:content].first[:text])
    assert data["errors"].any?
  end

  private

  def auth_headers
    { "authorization" => "Bearer #{@token.token}" }
  end

  def set_current_from_token(token)
    identity = token.identity
    user = identity.users.first
    Current.identity = identity
    Current.account = user.account
    Current.user = user
  end
end

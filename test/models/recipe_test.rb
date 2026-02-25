require "test_helper"

class RecipeTest < ActiveSupport::TestCase
  test "belongs to account" do
    recipe = recipes(:one)
    assert_respond_to recipe, :account
    assert_not_nil recipe.account
  end

  test "has many ingredients" do
    recipe = recipes(:one)
    assert_respond_to recipe, :ingredients
  end

  test "has many instructions" do
    recipe = recipes(:one)
    assert_respond_to recipe, :instructions
  end

  test "has one nutrition_data" do
    recipe = recipes(:one)
    assert_respond_to recipe, :nutrition_data
  end

  test "has many tips" do
    recipe = recipes(:one)
    assert_respond_to recipe, :tips
  end

  test "requires title" do
    recipe = Recipe.new(account: accounts(:one), category: :dinner)
    assert_not recipe.valid?
    assert_includes recipe.errors[:title], "can't be blank"
  end

  test "requires category" do
    recipe = Recipe.new(account: accounts(:one), title: "Test Recipe", category: nil)
    assert_not recipe.valid?
    assert_includes recipe.errors[:category], "can't be blank"
  end

  test "category enum includes expected values" do
    assert_equal %w[breakfast lunch dinner sides snacks sauces], Recipe.categories.keys
  end

  test "by_category scope filters recipes" do
    account = accounts(:one)
    breakfast = Recipe.create!(account: account, title: "Eggs", category: :breakfast)
    dinner = Recipe.create!(account: account, title: "Salmon", category: :dinner)

    assert_includes Recipe.by_category(:breakfast), breakfast
    assert_not_includes Recipe.by_category(:breakfast), dinner
  end

  test "total_time calculates prep + cook time" do
    recipe = Recipe.new(prep_time: 15, cook_time: 30)
    assert_equal 45, recipe.total_time
  end

  test "total_time handles nil values" do
    recipe = Recipe.new(prep_time: nil, cook_time: 30)
    assert_equal 30, recipe.total_time

    recipe = Recipe.new(prep_time: 15, cook_time: nil)
    assert_equal 15, recipe.total_time
  end

  test "ingredients_summary returns comma-separated names" do
    recipe = recipes(:one)
    recipe.ingredients.create!(name: "Salmon", quantity: "4", unit: "fillets")
    recipe.ingredients.create!(name: "Butter", quantity: "2", unit: "tbsp")

    summary = recipe.ingredients_summary
    assert_includes summary, "Salmon"
    assert_includes summary, "Butter"
  end

  test "to_api_response includes all recipe data" do
    recipe = recipes(:one)
    response = recipe.to_api_response

    assert_equal recipe.id, response[:id]
    assert_equal recipe.title, response[:title]
    assert_equal recipe.category, response[:category]
    assert response[:created_at].present?
  end

  test "to_meal_planning_response includes nutrition data" do
    recipe = recipes(:one)
    response = recipe.to_meal_planning_response

    assert_equal recipe.id, response[:id]
    assert_equal recipe.title, response[:title]
    assert_includes response[:url], recipe.account.external_account_id.to_s
  end

  test "has many tags through recipe_tags" do
    recipe = recipes(:one)
    assert_includes recipe.tags, tags(:keto)
    assert_includes recipe.tags, tags(:quick)
  end

  test "by_tags scope filters recipes by tag ids" do
    keto_tag = tags(:keto)
    dinner_party_tag = tags(:dinner_party)

    results = Recipe.by_tags([ keto_tag.id ])
    assert_includes results, recipes(:one)
    assert_includes results, recipes(:two)
    assert_not_includes results, recipes(:side_dish)

    results = Recipe.by_tags([ dinner_party_tag.id ])
    assert_empty results
  end

  test "by_tags scope returns all when nil" do
    assert_equal Recipe.all.to_a, Recipe.by_tags(nil).to_a
  end

  test "tag_list returns comma-separated tag names" do
    recipe = recipes(:one)
    list = recipe.tag_list
    assert_includes list, "keto"
    assert_includes list, "quick"
  end

  test "sync_tags_from_list creates and assigns tags" do
    account = accounts(:one)
    recipe = recipes(:side_dish)

    recipe.sync_tags_from_list("salad, tex-mex", account)
    assert_equal 2, recipe.tags.count
    assert_includes recipe.tags.pluck(:name), "salad"
    assert_includes recipe.tags.pluck(:name), "tex-mex"
  end

  test "sync_tags_from_list finds existing tags" do
    account = accounts(:one)
    recipe = recipes(:side_dish)

    assert_no_difference "Tag.count" do
      recipe.sync_tags_from_list("keto", account)
    end
    assert_includes recipe.tags, tags(:keto)
  end

  test "sync_tags_from_list removes old tags" do
    recipe = recipes(:one)
    account = accounts(:one)

    recipe.sync_tags_from_list("keto", account)
    assert_equal 1, recipe.tags.count
    assert_equal [ "keto" ], recipe.tags.pluck(:name)
  end

  test "sync_tags_from_list with blank string clears tags" do
    recipe = recipes(:one)
    account = accounts(:one)

    recipe.sync_tags_from_list("", account)
    assert_empty recipe.tags
  end

  test "to_api_response includes tags" do
    recipe = recipes(:one)
    response = recipe.to_api_response

    assert response[:tags].is_a?(Array)
    assert_includes response[:tags], "keto"
  end

  test "can have an attached image" do
    recipe = recipes(:one)
    assert_respond_to recipe, :image
    assert_not recipe.image.attached?

    recipe.image.attach(
      io: StringIO.new("fake image data"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )
    assert recipe.image.attached?
  end

  test "to_meal_planning_response includes tags" do
    recipe = recipes(:one)
    response = recipe.to_meal_planning_response

    assert response[:tags].is_a?(Array)
    assert_includes response[:tags], "keto"
  end
end

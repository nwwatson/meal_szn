require "test_helper"

class RecipesHelperTest < ActionView::TestCase
  include RecipesHelper

  test "CATEGORY_VISUALS has entry for each recipe category" do
    Recipe.categories.keys.each do |category|
      assert RecipesHelper::CATEGORY_VISUALS.key?(category),
        "Missing visual config for category: #{category}"
    end
  end

  test "each category visual has gradient and icon" do
    RecipesHelper::CATEGORY_VISUALS.each do |category, config|
      assert config[:gradient].present?, "Missing gradient for #{category}"
      assert config[:icon].present?, "Missing icon for #{category}"
    end
  end

  test "recipe_card_banner returns gradient div when no image" do
    recipe = recipes(:one)
    html = recipe_card_banner(recipe)
    assert_match(/bg-gradient-to-br/, html)
  end

  test "recipe_card_banner accepts custom height" do
    recipe = recipes(:one)
    html = recipe_card_banner(recipe, height: "h-48")
    assert_match(/h-48/, html)
  end

  test "recipe_show_banner returns gradient div when no image" do
    recipe = recipes(:one)
    html = recipe_show_banner(recipe)
    assert_match(/bg-gradient-to-br/, html)
    assert_match(/rounded-t-lg/, html)
  end

  test "recipe_card_banner shows image when attached" do
    recipe = recipes(:one)
    recipe.image.attach(
      io: StringIO.new("fake image data"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )

    html = recipe_card_banner(recipe)
    assert_no_match(/bg-gradient-to-br/, html)
    assert_match(/object-cover/, html)
  end
end

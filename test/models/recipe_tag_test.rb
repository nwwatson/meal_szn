require "test_helper"

class RecipeTagTest < ActiveSupport::TestCase
  test "belongs to recipe" do
    rt = recipe_tags(:salmon_keto)
    assert_equal recipes(:one), rt.recipe
  end

  test "belongs to tag" do
    rt = recipe_tags(:salmon_keto)
    assert_equal tags(:keto), rt.tag
  end

  test "tag_id must be unique per recipe" do
    duplicate = RecipeTag.new(recipe: recipes(:one), tag: tags(:keto))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:tag_id], "has already been taken"
  end
end

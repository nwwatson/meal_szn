require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "belongs to account" do
    tag = tags(:keto)
    assert_equal accounts(:one), tag.account
  end

  test "has many recipe_tags" do
    tag = tags(:keto)
    assert_includes tag.recipe_tags.map(&:recipe), recipes(:one)
  end

  test "has many recipes through recipe_tags" do
    tag = tags(:keto)
    assert_includes tag.recipes, recipes(:one)
    assert_includes tag.recipes, recipes(:two)
  end

  test "requires name" do
    tag = Tag.new(account: accounts(:one))
    assert_not tag.valid?
    assert_includes tag.errors[:name], "can't be blank"
  end

  test "normalizes name by stripping and downcasing" do
    tag = Tag.new(account: accounts(:one), name: "  Fancy Tag  ")
    tag.valid?
    assert_equal "fancy tag", tag.name
  end

  test "name must be unique within account (case-insensitive)" do
    Tag.create!(account: accounts(:one), name: "unique tag")
    duplicate = Tag.new(account: accounts(:one), name: "Unique Tag")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "same name allowed on different accounts" do
    tag = tags(:keto)
    other = tags(:other_account_tag)
    assert_equal tag.name, other.name
    assert_not_equal tag.account_id, other.account_id
  end

  test "alphabetical scope orders by name" do
    account = accounts(:one)
    names = account.tags.alphabetical.pluck(:name)
    assert_equal names.sort, names
  end

  test "with_recipe_count includes count" do
    tag = Tag.with_recipe_count.find(tags(:keto).id)
    assert_equal 2, tag.recipe_count
  end

  test "destroying tag destroys recipe_tags" do
    tag = tags(:keto)
    recipe_tag_ids = tag.recipe_tag_ids

    assert_difference "RecipeTag.count", -recipe_tag_ids.size do
      tag.destroy
    end
  end
end

require "test_helper"

class RecipeForkTest < ActiveSupport::TestCase
  setup do
    @source = recipes(:one)
    @target_account = accounts(:two)
  end

  test "creates a new recipe in the target account" do
    assert_difference -> { @target_account.recipes.count } do
      RecipeFork.call(@source, @target_account)
    end
  end

  test "copies recipe attributes" do
    forked = RecipeFork.call(@source, @target_account)

    assert_equal @source.title, forked.title
    assert_equal @source.description, forked.description
    assert_equal @source.category, forked.category
    assert_equal @source.source, forked.source
    assert_equal @source.servings, forked.servings
    assert_equal @source.prep_time, forked.prep_time
    assert_equal @source.cook_time, forked.cook_time
    assert_equal @target_account, forked.account
  end

  test "sets forked_from to source recipe" do
    forked = RecipeFork.call(@source, @target_account)
    assert_equal @source, forked.forked_from
  end

  test "sets shared_by when provided" do
    forked = RecipeFork.call(@source, @target_account, shared_by: "Alice")
    assert_equal "Alice", forked.shared_by
  end

  test "shared_by is nil when not provided" do
    forked = RecipeFork.call(@source, @target_account)
    assert_nil forked.shared_by
  end

  test "copies ingredients" do
    forked = RecipeFork.call(@source, @target_account)
    assert_equal @source.ingredients.count, forked.ingredients.count

    @source.ingredients.each_with_index do |src_ingredient, i|
      forked_ingredient = forked.ingredients[i]
      assert_equal src_ingredient.name, forked_ingredient.name
      assert_equal src_ingredient.quantity, forked_ingredient.quantity
      assert_equal src_ingredient.unit, forked_ingredient.unit
    end
  end

  test "copies instructions" do
    forked = RecipeFork.call(@source, @target_account)
    assert_equal @source.instructions.count, forked.instructions.count
  end

  test "copies nutrition data" do
    forked = RecipeFork.call(@source, @target_account)
    if @source.nutrition_data
      assert forked.nutrition_data.present?
      assert_equal @source.nutrition_data.calories, forked.nutrition_data.calories
    end
  end

  test "copies tips" do
    forked = RecipeFork.call(@source, @target_account)
    assert_equal @source.tips.count, forked.tips.count
  end

  test "copies tags to target account" do
    # Add a tag to source recipe first
    tag = @source.account.tags.create!(name: "test-tag")
    @source.tags << tag

    forked = RecipeFork.call(@source, @target_account)

    # Source tags should be present in the fork
    assert_includes forked.tags.reload.pluck(:name), "test-tag"

    # Forked tags belong to target account
    forked_tag = forked.tags.find_by(name: "test-tag")
    assert_equal @target_account.id, forked_tag.account_id
  end
end

require "test_helper"

class RecipeForkTest < ActiveSupport::TestCase
  setup do
    @source = recipes(:one) # salmon recipe - has ingredients, instructions, nutrition, tips, tags
    @target_account = accounts(:two)
  end

  test "creates a new recipe in the target account" do
    forked = RecipeFork.call(@source, @target_account)

    assert forked.persisted?
    assert_equal @target_account, forked.account
    assert_not_equal @source.id, forked.id
  end

  test "copies basic recipe attributes" do
    forked = RecipeFork.call(@source, @target_account)

    assert_equal @source.title, forked.title
    assert_equal @source.description, forked.description
    assert_equal @source.category, forked.category
    assert_equal @source.source, forked.source
    assert_equal @source.servings, forked.servings
    assert_equal @source.prep_time, forked.prep_time
    assert_equal @source.cook_time, forked.cook_time
  end

  test "sets forked_from to source recipe" do
    forked = RecipeFork.call(@source, @target_account)

    assert_equal @source, forked.forked_from
    assert_includes @source.forks, forked
  end

  test "copies all ingredients" do
    forked = RecipeFork.call(@source, @target_account)

    assert_equal @source.ingredients.count, forked.ingredients.count
    @source.ingredients.each do |ingredient|
      matching = forked.ingredients.find_by(name: ingredient.name)
      assert matching, "Expected ingredient '#{ingredient.name}' to be forked"
      assert_equal ingredient.quantity, matching.quantity
      assert_equal ingredient.unit, matching.unit
      assert_equal ingredient.display_order, matching.display_order
    end
  end

  test "copies all instructions" do
    forked = RecipeFork.call(@source, @target_account)

    assert_equal @source.instructions.count, forked.instructions.count
    @source.instructions.each do |instruction|
      matching = forked.instructions.find_by(step_number: instruction.step_number)
      assert matching, "Expected instruction step #{instruction.step_number} to be forked"
      assert_equal instruction.instruction, matching.instruction
    end
  end

  test "copies nutrition data" do
    forked = RecipeFork.call(@source, @target_account)

    assert forked.nutrition_data.present?
    assert_equal @source.nutrition_data.calories, forked.nutrition_data.calories
    assert_equal @source.nutrition_data.fat, forked.nutrition_data.fat
    assert_equal @source.nutrition_data.protein, forked.nutrition_data.protein
    assert_equal @source.nutrition_data.carbs, forked.nutrition_data.carbs
  end

  test "copies tips" do
    forked = RecipeFork.call(@source, @target_account)

    assert_equal @source.tips.count, forked.tips.count
    @source.tips.each do |tip|
      assert forked.tips.find_by(tip: tip.tip), "Expected tip to be forked"
    end
  end

  test "creates tags in target account" do
    forked = RecipeFork.call(@source, @target_account)

    # All source tags should be present in forked recipe
    # (additional diet tags may be added by the categorizer callback)
    @source.tags.each do |tag|
      target_tag = @target_account.tags.find_by(name: tag.name)
      assert target_tag, "Expected tag '#{tag.name}' to exist in target account"
      assert_includes forked.tags, target_tag
    end
    assert forked.tags.count >= @source.tags.count
  end

  test "handles recipe without nutrition data" do
    source = recipes(:side_dish)
    # Ensure no nutrition data so the nil path is tested
    source.nutrition_data&.destroy
    source.reload

    forked = RecipeFork.call(source, @target_account)

    assert forked.persisted?
    assert_nil forked.nutrition_data
  end

  test "handles recipe without manually added tags" do
    source = recipes(:side_dish)
    source_manual_tags = source.tags.where.not("name LIKE ?", "diet:%")

    forked = RecipeFork.call(source, @target_account)

    assert forked.persisted?
    # No manually-added tags to fork, but diet tags may be added by categorizer callback
    forked_manual_tags = forked.tags.where.not("name LIKE ?", "diet:%")
    assert_equal source_manual_tags.count, forked_manual_tags.count
  end

  test "does not modify source recipe" do
    original_title = @source.title
    original_ingredient_count = @source.ingredients.count

    RecipeFork.call(@source, @target_account)

    @source.reload
    assert_equal original_title, @source.title
    assert_equal original_ingredient_count, @source.ingredients.count
  end

  test "child records have different IDs from source" do
    forked = RecipeFork.call(@source, @target_account)

    forked.ingredients.each do |ingredient|
      assert_not_includes @source.ingredients.pluck(:id), ingredient.id
    end
  end
end

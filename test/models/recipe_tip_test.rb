require "test_helper"

class RecipeTipTest < ActiveSupport::TestCase
  test "belongs to recipe" do
    tip = recipe_tips(:salmon_tip)
    assert_equal recipes(:one), tip.recipe
  end

  test "requires tip text" do
    tip = RecipeTip.new(recipe: recipes(:side_dish))
    assert_not tip.valid?
    assert_includes tip.errors[:tip], "can't be blank"
  end

  test "generates UUID id on create" do
    tip = RecipeTip.create!(recipe: recipes(:side_dish), tip: "A useful tip")
    assert tip.id.present?
    assert_match(/\A[0-9a-f-]{36}\z/, tip.id)
  end

  test "valid with tip and recipe" do
    tip = RecipeTip.new(recipe: recipes(:side_dish), tip: "Season well")
    assert tip.valid?
  end
end

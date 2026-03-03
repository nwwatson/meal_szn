require "test_helper"

class RecipeShareMailerTest < ActionMailer::TestCase
  setup do
    @share = recipe_shares(:pending_share)
  end

  test "invitation email has correct recipient" do
    email = RecipeShareMailer.invitation(@share)
    assert_equal [ @share.recipient_email ], email.to
  end

  test "invitation email has correct subject" do
    email = RecipeShareMailer.invitation(@share)
    assert_equal "#{@share.sender.name} shared a recipe with you on MealSzn", email.subject
  end

  test "invitation email contains recipe title" do
    email = RecipeShareMailer.invitation(@share)
    assert_match @share.recipe.title, email.html_part.body.to_s
    assert_match @share.recipe.title, email.text_part.body.to_s
  end

  test "invitation email contains share link" do
    email = RecipeShareMailer.invitation(@share)
    assert_match @share.token, email.html_part.body.to_s
    assert_match @share.token, email.text_part.body.to_s
  end

  test "invitation email contains sender name" do
    email = RecipeShareMailer.invitation(@share)
    assert_match @share.sender.name, email.html_part.body.to_s
  end
end

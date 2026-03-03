require "test_helper"

class RecipeShareTest < ActiveSupport::TestCase
  setup do
    @share = recipe_shares(:pending_share)
    @recipe = recipes(:one)
    @sender = users(:one)
  end

  test "valid share" do
    share = RecipeShare.new(
      recipe: @recipe,
      sender: @sender,
      recipient_email: "test@example.com"
    )
    assert share.valid?
  end

  test "requires recipient email" do
    share = RecipeShare.new(recipe: @recipe, sender: @sender, recipient_email: nil)
    assert_not share.valid?
    assert_includes share.errors[:recipient_email], "can't be blank"
  end

  test "validates email format" do
    share = RecipeShare.new(recipe: @recipe, sender: @sender, recipient_email: "notanemail")
    assert_not share.valid?
  end

  test "normalizes email" do
    share = RecipeShare.new(
      recipe: @recipe,
      sender: @sender,
      recipient_email: "  TEST@EXAMPLE.COM  "
    )
    assert_equal "test@example.com", share.recipient_email
  end

  test "generates token on create" do
    share = RecipeShare.create!(
      recipe: @recipe,
      sender: @sender,
      recipient_email: "unique@example.com"
    )
    assert share.token.present?
    assert share.token.length > 20
  end

  test "sets expiration on create" do
    share = RecipeShare.create!(
      recipe: @recipe,
      sender: @sender,
      recipient_email: "expiry@example.com"
    )
    assert share.expires_at.present?
    assert_in_delta 30.days.from_now, share.expires_at, 5.seconds
  end

  test "token is unique" do
    share1 = RecipeShare.create!(recipe: @recipe, sender: @sender, recipient_email: "a@example.com")
    share2 = RecipeShare.create!(recipe: @recipe, sender: @sender, recipient_email: "b@example.com")
    assert_not_equal share1.token, share2.token
  end

  test "expired? returns true when past expiration" do
    expired = recipe_shares(:expired_share)
    assert expired.expired?
  end

  test "expired? returns false when not yet expired" do
    assert_not @share.expired?
  end

  test "redeemable? returns true for pending non-expired share" do
    assert @share.redeemable?
  end

  test "redeemable? returns false for expired share" do
    expired = recipe_shares(:expired_share)
    assert_not expired.redeemable?
  end

  test "redeemable? returns false for accepted share" do
    accepted = recipe_shares(:accepted_share)
    assert_not accepted.redeemable?
  end

  test "accept! updates status and sets accepted_at" do
    recipient = users(:two)
    @share.accept!(recipient_user: recipient)
    @share.reload
    assert @share.accepted?
    assert @share.accepted_at.present?
    assert_equal recipient, @share.recipient_user
  end

  test "decline! updates status" do
    @share.decline!
    @share.reload
    assert @share.declined?
  end

  test "active scope returns only pending non-expired shares" do
    active = RecipeShare.active
    assert_includes active, @share
    assert_not_includes active, recipe_shares(:expired_share)
    assert_not_includes active, recipe_shares(:accepted_share)
  end

  test "sender_name returns sender's name" do
    assert_equal @share.sender.name, @share.sender_name
  end
end

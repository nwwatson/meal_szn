require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  test "generates id on create" do
    invitation = Invitation.create!(
      account: accounts(:one),
      invited_by: users(:one),
      email_address: "new@example.com"
    )
    assert invitation.id.present?
    assert_match(/\A[0-9a-f-]{36}\z/, invitation.id)
  end

  test "generates token on create" do
    invitation = Invitation.create!(
      account: accounts(:one),
      invited_by: users(:one),
      email_address: "new@example.com"
    )
    assert invitation.token.present?
  end

  test "sets expiration on create" do
    invitation = Invitation.create!(
      account: accounts(:one),
      invited_by: users(:one),
      email_address: "new@example.com"
    )
    assert invitation.expires_at.present?
    assert invitation.expires_at > 6.days.from_now
  end

  test "normalizes email address" do
    invitation = Invitation.create!(
      account: accounts(:one),
      invited_by: users(:one),
      email_address: "  TEST@Example.COM  "
    )
    assert_equal "test@example.com", invitation.email_address
  end

  test "validates email format" do
    invitation = Invitation.new(
      account: accounts(:one),
      invited_by: users(:one),
      email_address: "not-an-email"
    )
    assert_not invitation.valid?
    assert invitation.errors[:email_address].any?
  end

  test "expired? returns true when past expiration" do
    invitation = invitations(:expired_invitation)
    assert invitation.expired?
  end

  test "expired? returns false when not expired" do
    invitation = invitations(:pending_invitation)
    assert_not invitation.expired?
  end

  test "accepted? returns true when accepted_at is set" do
    invitation = invitations(:accepted_invitation)
    assert invitation.accepted?
  end

  test "redeemable? returns true for pending non-expired invitation" do
    invitation = invitations(:pending_invitation)
    assert invitation.redeemable?
  end

  test "redeemable? returns false for accepted invitation" do
    invitation = invitations(:accepted_invitation)
    assert_not invitation.redeemable?
  end

  test "redeemable? returns false for expired invitation" do
    invitation = invitations(:expired_invitation)
    assert_not invitation.redeemable?
  end

  test "accept! sets accepted_at" do
    invitation = invitations(:pending_invitation)
    invitation.accept!
    assert invitation.accepted_at.present?
  end

  test "pending scope returns only pending non-expired invitations" do
    pending = Invitation.pending
    assert_includes pending, invitations(:pending_invitation)
    assert_not_includes pending, invitations(:accepted_invitation)
    assert_not_includes pending, invitations(:expired_invitation)
  end

  test "token is unique" do
    invitation = Invitation.new(
      account: accounts(:one),
      invited_by: users(:one),
      email_address: "unique@example.com",
      token: invitations(:pending_invitation).token
    )
    assert_not invitation.valid?
  end
end

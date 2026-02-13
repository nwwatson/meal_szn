require "test_helper"

class OnboardingTest < ActiveSupport::TestCase
  test "validates email_address presence on identity_creation" do
    onboarding = Onboarding.new(email_address: "")
    assert_not onboarding.valid?(:identity_creation)
    assert_includes onboarding.errors[:email_address], "can't be blank"
  end

  test "validates email_address format on identity_creation" do
    onboarding = Onboarding.new(email_address: "bad-email")
    assert_not onboarding.valid?(:identity_creation)
    assert onboarding.errors[:email_address].any?
  end

  test "validates full_name on completion" do
    onboarding = Onboarding.new(identity: identities(:one), organization_name: "Org")
    assert_not onboarding.valid?(:completion)
    assert_includes onboarding.errors[:full_name], "can't be blank"
  end

  test "validates organization_name on completion" do
    onboarding = Onboarding.new(identity: identities(:one), full_name: "Test")
    assert_not onboarding.valid?(:completion)
    assert_includes onboarding.errors[:organization_name], "can't be blank"
  end

  test "validates identity on completion" do
    onboarding = Onboarding.new(full_name: "Test", organization_name: "Org")
    assert_not onboarding.valid?(:completion)
    assert_includes onboarding.errors[:identity], "can't be blank"
  end

  test "normalizes email_address" do
    onboarding = Onboarding.new(email_address: "  ONBOARD@Example.COM  ")
    onboarding.valid?(:identity_creation)
    assert_equal "onboard@example.com", onboarding.email_address
  end

  test "create_identity sends onboarding magic link" do
    onboarding = Onboarding.new(email_address: "test@example.com")

    assert_difference "MagicLink.count" do
      assert onboarding.create_identity
    end

    latest_ml = onboarding.identity.magic_links.order(created_at: :desc).first
    assert latest_ml.onboarding?
  end

  test "create_identity returns false with invalid email" do
    onboarding = Onboarding.new(email_address: "")
    assert_not onboarding.create_identity
  end

  test "complete returns false when accounts already exist" do
    # Accounts already exist from fixtures, so requires_onboarding? is false
    identity = Identity.create!(email_address: "onboard-test@example.com")
    onboarding = Onboarding.new(
      identity: identity,
      full_name: "Onboard User",
      organization_name: "Onboard Org"
    )
    assert_not onboarding.complete
  end

  test "complete returns false without valid attributes" do
    onboarding = Onboarding.new(full_name: "Test")
    assert_not onboarding.complete
  end
end

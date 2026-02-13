require "test_helper"

class SignupTest < ActiveSupport::TestCase
  test "validates email_address presence on identity_creation" do
    signup = Signup.new(email_address: "")
    assert_not signup.valid?(:identity_creation)
    assert_includes signup.errors[:email_address], "can't be blank"
  end

  test "validates email_address format on identity_creation" do
    signup = Signup.new(email_address: "not-an-email")
    assert_not signup.valid?(:identity_creation)
    assert signup.errors[:email_address].any?
  end

  test "validates full_name presence on completion" do
    signup = Signup.new(identity: identities(:one), full_name: "")
    assert_not signup.valid?(:completion)
    assert_includes signup.errors[:full_name], "can't be blank"
  end

  test "validates identity presence on completion" do
    signup = Signup.new(full_name: "Test User")
    assert_not signup.valid?(:completion)
    assert_includes signup.errors[:identity], "can't be blank"
  end

  test "normalizes email_address" do
    signup = Signup.new(email_address: "  TEST@Example.COM  ")
    signup.valid?(:identity_creation)
    assert_equal "test@example.com", signup.email_address
  end

  test "create_identity finds existing identity and sends magic link" do
    signup = Signup.new(email_address: "test@example.com")

    assert_difference "MagicLink.count" do
      assert signup.create_identity
    end

    assert_equal identities(:one), signup.identity
  end

  test "create_identity creates new identity for unknown email" do
    signup = Signup.new(email_address: "newuser@example.com")

    assert_difference [ "Identity.count", "MagicLink.count" ] do
      assert signup.create_identity
    end
  end

  test "create_identity returns false with invalid email" do
    signup = Signup.new(email_address: "")
    assert_not signup.create_identity
  end

  test "complete creates account with owner and system users" do
    identity = Identity.create!(email_address: "signup-complete@example.com")
    signup = Signup.new(identity: identity, full_name: "New Signup")

    assert_difference "Account.count" do
      assert_difference "User.count", 2 do
        account = signup.complete
        assert account.is_a?(Account)
        assert account.persisted?
      end
    end
  end

  test "complete returns false without full_name" do
    signup = Signup.new(identity: identities(:one))
    assert_not signup.complete
  end
end

require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  setup do
    Current.reset
  end

  teardown do
    Current.reset
  end

  test "setting session sets identity" do
    session = sessions(:one)
    Current.session = session
    assert_equal session.identity, Current.identity
  end

  test "setting session to nil clears identity" do
    Current.session = sessions(:one)
    Current.session = nil
    assert_nil Current.identity
  end

  test "account attribute can be set" do
    Current.account = accounts(:one)
    assert_equal accounts(:one), Current.account
  end

  test "setting identity with account sets user" do
    Current.account = accounts(:one)
    Current.identity = identities(:one)
    assert Current.user.present?
    assert_equal users(:one), Current.user
  end

  test "setting identity without account does not set user" do
    Current.identity = identities(:one)
    assert_nil Current.user
  end

  test "reset clears all attributes" do
    Current.session = sessions(:one)
    Current.account = accounts(:one)
    Current.reset
    assert_nil Current.session
    assert_nil Current.identity
    assert_nil Current.user
    assert_nil Current.account
  end
end

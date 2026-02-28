require "test_helper"

class ApplicationToolTest < ActiveSupport::TestCase
  setup do
    @write_token = identity_access_tokens(:write_token)
    @read_token = identity_access_tokens(:read_token)
    @account = accounts(:one)
  end

  test "authorizes with valid write token" do
    tool = ListRecipesTool.new(headers: auth_headers(@write_token))
    assert tool.authorized?
    assert_equal @account, Current.account
  end

  test "authorizes with valid read token" do
    tool = ListRecipesTool.new(headers: auth_headers(@read_token))
    assert tool.authorized?
  end

  test "rejects missing authorization header" do
    tool = ListRecipesTool.new(headers: {})
    assert_not tool.authorized?
  end

  test "rejects invalid token" do
    tool = ListRecipesTool.new(headers: { "authorization" => "Bearer invalid_token" })
    assert_not tool.authorized?
  end

  test "rejects revoked token" do
    revoked = identity_access_tokens(:revoked_token)
    tool = ListRecipesTool.new(headers: auth_headers(revoked))
    assert_not tool.authorized?
  end

  test "rejects expired token" do
    expired = identity_access_tokens(:expired_token)
    tool = ListRecipesTool.new(headers: auth_headers(expired))
    assert_not tool.authorized?
  end

  test "sets Current attributes on authorization" do
    tool = ListRecipesTool.new(headers: auth_headers(@write_token))
    tool.authorized?

    assert_equal @account, Current.account
    assert_not_nil Current.identity
    assert_not_nil Current.user
  end

  private

  def auth_headers(token)
    { "authorization" => "Bearer #{token.token}" }
  end
end

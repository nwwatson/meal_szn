require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  test "requires email address" do
    identity = Identity.new
    assert_not identity.valid?
    assert_includes identity.errors[:email_address], "can't be blank"
  end

  test "requires valid email format" do
    identity = Identity.new(email_address: "invalid-email")
    assert_not identity.valid?
    assert_includes identity.errors[:email_address], "is invalid"
  end

  test "requires unique email address" do
    existing = identities(:one)
    identity = Identity.new(email_address: existing.email_address)
    assert_not identity.valid?
    assert_includes identity.errors[:email_address], "has already been taken"
  end

  test "normalizes email address to lowercase" do
    identity = Identity.create!(email_address: "Normalize@Example.COM")
    assert_equal "normalize@example.com", identity.email_address
  end

  test "generates id on create" do
    identity = Identity.create!(email_address: "genid@example.com")
    assert identity.id.present?
  end

  test "can send magic link" do
    identity = identities(:one)
    assert_difference "MagicLink.count" do
      magic_link = identity.send_magic_link(purpose: :sign_in)
      assert magic_link.persisted?
      assert_equal "sign_in", magic_link.purpose
    end
  end

  test "has many sessions" do
    identity = identities(:one)
    assert_respond_to identity, :sessions
  end

  test "has many magic links" do
    identity = identities(:one)
    assert_respond_to identity, :magic_links
  end

  test "has many access tokens" do
    identity = identities(:one)
    assert_respond_to identity, :access_tokens
  end

  test "has many users" do
    identity = identities(:one)
    assert_respond_to identity, :users
  end

  test "staff defaults to false" do
    identity = Identity.create!(email_address: "staff-test@example.com")
    assert_equal false, identity.staff
  end
end

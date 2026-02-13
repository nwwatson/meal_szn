require "test_helper"

class Identity::AccessTokenTest < ActiveSupport::TestCase
  test "belongs to identity" do
    identity = identities(:one)
    token = Identity::AccessToken.create!(identity: identity, name: "Test Token", permission: :read)
    assert_equal identity, token.identity
  end

  test "generates secure token on create" do
    identity = identities(:one)
    token = Identity::AccessToken.create!(identity: identity, name: "Test Token", permission: :read)
    assert token.token.present?
    assert token.token.length >= 20
  end

  test "requires permission" do
    identity = identities(:one)
    token = Identity::AccessToken.new(identity: identity, name: "Test Token", permission: nil)
    assert_not token.valid?
    assert_includes token.errors[:permission], "can't be blank"
  end

  test "permission enum includes read and write" do
    assert_equal %w[read write], Identity::AccessToken.permissions.keys
  end

  test "defaults to read permission" do
    identity = identities(:one)
    token = identity.access_tokens.build
    assert_equal "read", token.permission
  end

  test "active scope excludes revoked tokens" do
    identity = identities(:one)
    active_token = Identity::AccessToken.create!(identity: identity, name: "Active", permission: :read)
    revoked_token = Identity::AccessToken.create!(identity: identity, name: "Revoked", permission: :read, revoked_at: Time.current)

    assert_includes Identity::AccessToken.active, active_token
    assert_not_includes Identity::AccessToken.active, revoked_token
  end

  test "active scope excludes expired tokens" do
    identity = identities(:one)
    active_token = Identity::AccessToken.create!(identity: identity, name: "Active", permission: :read)
    expired_token = Identity::AccessToken.create!(identity: identity, name: "Expired", permission: :read, expires_at: 1.day.ago)

    assert_includes Identity::AccessToken.active, active_token
    assert_not_includes Identity::AccessToken.active, expired_token
  end

  test "revoke! sets revoked_at" do
    identity = identities(:one)
    token = Identity::AccessToken.create!(identity: identity, name: "Test Token", permission: :read)

    assert_nil token.revoked_at
    token.revoke!
    assert_not_nil token.revoked_at
  end

  test "revoked? returns true for revoked tokens" do
    token = Identity::AccessToken.new(revoked_at: Time.current)
    assert token.revoked?
  end

  test "revoked? returns false for active tokens" do
    token = Identity::AccessToken.new(revoked_at: nil)
    assert_not token.revoked?
  end

  test "expired? returns true for expired tokens" do
    token = Identity::AccessToken.new(expires_at: 1.day.ago)
    assert token.expired?
  end

  test "expired? returns false for non-expired tokens" do
    token = Identity::AccessToken.new(expires_at: 1.day.from_now)
    assert_not token.expired?
  end

  test "expired? returns false when no expiration set" do
    token = Identity::AccessToken.new(expires_at: nil)
    assert_not token.expired?
  end

  test "can_read? returns true for read tokens" do
    token = Identity::AccessToken.new(permission: :read)
    assert token.can_read?
  end

  test "can_read? returns true for write tokens" do
    token = Identity::AccessToken.new(permission: :write)
    assert token.can_read?
  end

  test "can_write? returns false for read tokens" do
    token = Identity::AccessToken.new(permission: :read)
    assert_not token.can_write?
  end

  test "can_write? returns true for write tokens" do
    token = Identity::AccessToken.new(permission: :write)
    assert token.can_write?
  end

  test "requires name" do
    identity = identities(:one)
    token = Identity::AccessToken.new(identity: identity, permission: :read, name: nil)
    assert_not token.valid?
    assert_includes token.errors[:name], "can't be blank"
  end

  test "stores name" do
    identity = identities(:one)
    token = Identity::AccessToken.create!(identity: identity, permission: :read, name: "My API Token")
    assert_equal "My API Token", token.name
  end
end

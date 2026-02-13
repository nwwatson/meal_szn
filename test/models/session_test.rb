require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "belongs to identity" do
    session = sessions(:one)
    assert_respond_to session, :identity
    assert_not_nil session.identity
  end

  test "generates id on create" do
    identity = identities(:one)
    session = Session.create!(identity: identity, ip_address: "127.0.0.1", user_agent: "Test")
    assert session.id.present?
  end

  test "sets default expiration to 2 weeks" do
    identity = identities(:one)
    session = Session.create!(identity: identity, ip_address: "127.0.0.1", user_agent: "Test")
    assert_in_delta 2.weeks.from_now, session.expires_at, 1.minute
  end

  test "active scope excludes expired sessions" do
    identity = identities(:one)
    active_session = Session.create!(identity: identity, ip_address: "127.0.0.1", user_agent: "Test")
    expired_session = Session.create!(identity: identity, ip_address: "127.0.0.2", user_agent: "Test", expires_at: 1.day.ago)

    assert_includes Session.active, active_session
    assert_not_includes Session.active, expired_session
  end

  test "expired? returns true for expired sessions" do
    session = Session.new(expires_at: 1.day.ago)
    assert session.expired?
  end

  test "expired? returns false for active sessions" do
    session = Session.new(expires_at: 1.day.from_now)
    assert_not session.expired?
  end

  test "refresh_activity extends expiration" do
    identity = identities(:one)
    session = Session.create!(identity: identity, ip_address: "127.0.0.1", user_agent: "Test", expires_at: 1.day.from_now)
    original_expiry = session.expires_at

    # Make last_active_at old enough to trigger refresh
    session.update_column(:last_active_at, 2.hours.ago)
    session.refresh_activity!

    assert session.expires_at > original_expiry
    assert_in_delta 2.weeks.from_now, session.expires_at, 1.minute
  end

  test "stores ip address" do
    identity = identities(:one)
    session = Session.create!(identity: identity, ip_address: "192.168.1.1", user_agent: "Test")
    assert_equal "192.168.1.1", session.ip_address
  end

  test "stores user agent" do
    identity = identities(:one)
    session = Session.create!(identity: identity, ip_address: "127.0.0.1", user_agent: "Mozilla/5.0")
    assert_equal "Mozilla/5.0", session.user_agent
  end
end

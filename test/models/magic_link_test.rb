require "test_helper"

class MagicLinkTest < ActiveSupport::TestCase
  test "belongs to identity" do
    magic_link = magic_links(:one)
    assert_respond_to magic_link, :identity
    assert_not_nil magic_link.identity
  end

  test "generates 6-character code" do
    identity = identities(:one)
    magic_link = MagicLink.create!(identity: identity, purpose: :sign_in)
    assert_equal 6, magic_link.code.length
    assert_match(/\A[A-Z0-9]{6}\z/, magic_link.code)
  end

  test "generates unique code" do
    identity = identities(:one)
    codes = 10.times.map do
      MagicLink.create!(identity: identity, purpose: :sign_in).code
    end
    assert_equal codes.uniq.length, codes.length
  end

  test "excludes ambiguous characters from code" do
    identity = identities(:one)
    # Generate many codes to test character exclusion
    100.times do
      magic_link = MagicLink.create!(identity: identity, purpose: :sign_in)
      assert_no_match(/[OIL]/, magic_link.code)
    end
  end

  test "sets default expiration to 15 minutes" do
    identity = identities(:one)
    magic_link = MagicLink.create!(identity: identity, purpose: :sign_in)
    assert_in_delta 15.minutes.from_now, magic_link.expires_at, 1.second
  end

  test "requires purpose" do
    identity = identities(:one)
    magic_link = MagicLink.new(identity: identity, purpose: nil)
    assert_not magic_link.valid?
    assert_includes magic_link.errors[:purpose], "can't be blank"
  end

  test "purpose enum includes expected values" do
    assert_equal %w[sign_in sign_up onboarding], MagicLink.purposes.keys
  end

  test "active scope excludes expired magic links" do
    identity = identities(:one)
    active_link = MagicLink.create!(identity: identity, purpose: :sign_in)
    expired_link = MagicLink.create!(identity: identity, purpose: :sign_in, expires_at: 1.minute.ago)

    assert_includes MagicLink.active, active_link
    assert_not_includes MagicLink.active, expired_link
  end

  test "expired? returns true for expired links" do
    magic_link = MagicLink.new(expires_at: 1.minute.ago)
    assert magic_link.expired?
  end

  test "expired? returns false for active links" do
    magic_link = MagicLink.new(expires_at: 1.minute.from_now)
    assert_not magic_link.expired?
  end
end

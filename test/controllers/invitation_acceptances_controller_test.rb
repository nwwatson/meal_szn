require "test_helper"

class InvitationAcceptancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @invitation = invitations(:pending_invitation)
    @account = accounts(:one)
  end

  test "redirects to sign in when unauthenticated" do
    get "/invitations/#{@invitation.token}/accept"
    assert_redirected_to new_session_path
  end

  test "shows invitation details when authenticated" do
    identity = Identity.create!(email_address: "invited@example.com")
    session = identity.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", expires_at: 2.weeks.from_now)
    sign_in_as(session)

    get "/invitations/#{@invitation.token}/accept"
    assert_response :success
    assert_match @account.name, response.body
    assert_match "invited", response.body
  end

  test "user can accept invitation and join account" do
    identity = Identity.create!(email_address: "invited@example.com")
    session = identity.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", expires_at: 2.weeks.from_now)
    sign_in_as(session)

    assert_difference "User.count", 1 do
      patch "/invitations/#{@invitation.token}/accept"
    end

    new_user = @account.users.find_by(identity: identity)
    assert new_user.present?
    assert new_user.member?
    assert @invitation.reload.accepted?
    assert_redirected_to "/#{@account.external_account_id}"
  end

  test "expired invitation shows error" do
    expired = invitations(:expired_invitation)
    identity = Identity.create!(email_address: "expired@example.com")
    session = identity.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", expires_at: 2.weeks.from_now)
    sign_in_as(session)

    get "/invitations/#{expired.token}/accept"
    assert_response :success
    assert_match "expired", response.body
  end

  test "accepted invitation shows already used message" do
    accepted = invitations(:accepted_invitation)
    identity = Identity.create!(email_address: "accepted@example.com")
    session = identity.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", expires_at: 2.weeks.from_now)
    sign_in_as(session)

    get "/invitations/#{accepted.token}/accept"
    assert_response :success
    assert_match "already been used", response.body
  end

  test "cannot accept expired invitation via PATCH" do
    expired = invitations(:expired_invitation)
    identity = Identity.create!(email_address: "expired@example.com")
    session = identity.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", expires_at: 2.weeks.from_now)
    sign_in_as(session)

    assert_no_difference "User.count" do
      patch "/invitations/#{expired.token}/accept"
    end
    assert_redirected_to new_session_path
  end

  test "deactivates existing membership when accepting" do
    identity = Identity.create!(email_address: "switcher2@example.com")
    other_account = accounts(:two)
    old_user = other_account.users.create!(identity: identity, name: "Switcher", role: :member, verified_at: Time.current)
    session = identity.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", expires_at: 2.weeks.from_now)
    sign_in_as(session)

    patch "/invitations/#{@invitation.token}/accept"

    assert_not old_user.reload.active?
    new_user = @account.users.find_by(identity: identity)
    assert new_user.present?
    assert new_user.active?
  end

  test "invalid token returns redirect" do
    identity = Identity.create!(email_address: "nobody@example.com")
    session = identity.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", expires_at: 2.weeks.from_now)
    sign_in_as(session)

    get "/invitations/nonexistent_token/accept"
    assert_redirected_to new_session_path
    assert_match "not found", flash[:alert]
  end
end

require "test_helper"

class Accounts::InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
  end

  def account_path_prefix
    "/#{@account.external_account_id}"
  end

  test "owner can send an invitation" do
    sign_in_as(@session)
    assert_difference "Invitation.count", 1 do
      post "#{account_path_prefix}/invitations", params: { email_address: "newmember@example.com" }
    end
    assert_redirected_to "#{account_path_prefix}/members"
    assert_match "Invitation sent", flash[:notice]
  end

  test "sends invitation email" do
    sign_in_as(@session)
    assert_enqueued_emails 1 do
      post "#{account_path_prefix}/invitations", params: { email_address: "newmember@example.com" }
    end
  end

  test "prevents inviting existing member" do
    sign_in_as(@session)
    assert_no_difference "Invitation.count" do
      post "#{account_path_prefix}/invitations", params: { email_address: identities(:two).email_address }
    end
    assert_redirected_to "#{account_path_prefix}/members"
    assert_match "already a member", flash[:alert]
  end

  test "prevents blank email" do
    sign_in_as(@session)
    assert_no_difference "Invitation.count" do
      post "#{account_path_prefix}/invitations", params: { email_address: "" }
    end
    assert_redirected_to "#{account_path_prefix}/members"
  end

  test "owner can cancel a pending invitation" do
    sign_in_as(@session)
    invitation = invitations(:pending_invitation)
    assert_difference "Invitation.count", -1 do
      delete "#{account_path_prefix}/invitations/#{invitation.id}"
    end
    assert_redirected_to "#{account_path_prefix}/members"
  end

  test "non-admin cannot send invitations" do
    member_session = identities(:two).sessions.create!(
      user_agent: "test",
      ip_address: "127.0.0.1",
      expires_at: 2.weeks.from_now
    )
    sign_in_as(member_session)
    assert_no_difference "Invitation.count" do
      post "#{account_path_prefix}/invitations", params: { email_address: "new@example.com" }
    end
    assert_response :forbidden
  end
end

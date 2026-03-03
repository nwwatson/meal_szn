require "test_helper"

class InvitationMailerTest < ActionMailer::TestCase
  test "invite sends email with correct content" do
    invitation = invitations(:pending_invitation)
    email = InvitationMailer.invite(invitation)

    assert_equal [ "invited@example.com" ], email.to
    assert_match "invited to join", email.subject
    assert_match invitation.account.name, email.subject

    # HTML body should contain key elements
    html_body = email.html_part.body.to_s
    assert_match invitation.invited_by.name, html_body
    assert_match invitation.account.name, html_body
    assert_match "Accept Invitation", html_body
    assert_match invitation.token, html_body

    # Text body should also contain key content
    text_body = email.text_part.body.to_s
    assert_match invitation.account.name, text_body
    assert_match invitation.token, text_body
  end
end

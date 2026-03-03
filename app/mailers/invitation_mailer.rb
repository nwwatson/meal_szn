class InvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @account = invitation.account
    @inviter = invitation.invited_by
    @accept_url = invitation_acceptance_url(token: invitation.token)

    mail(
      to: invitation.email_address,
      subject: "You've been invited to join #{@account.name} on MealSzn"
    )
  end
end

class Accounts::InvitationsController < ApplicationController
  before_action :ensure_admin

  def create
    email = params[:email_address]&.strip&.downcase

    if email.blank?
      redirect_to members_path, alert: "Please provide an email address."
      return
    end

    # Check if already a member
    if Current.account.identities.exists?(email_address: email)
      redirect_to members_path, alert: "This person is already a member of your account."
      return
    end

    invitation = Current.account.invitations.create!(
      invited_by: Current.user,
      email_address: email
    )

    InvitationMailer.invite(invitation).deliver_later
    redirect_to members_path, notice: "Invitation sent to #{email}."
  end

  def destroy
    invitation = Current.account.invitations.pending.find(params[:id])
    invitation.destroy
    redirect_to members_path, notice: "Invitation cancelled."
  end
end

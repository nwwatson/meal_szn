class InvitationAcceptancesController < ApplicationController
  disallow_account_scope
  skip_onboarding_redirect
  allow_unauthorized_access

  layout "public"

  before_action :require_authenticated_identity
  before_action :set_invitation

  def show
    @has_existing_account = Current.identity.users.where(active: true).exists?
    @existing_account = Current.identity.users.find_by(active: true)&.account
  end

  def update
    unless @invitation.redeemable?
      redirect_to new_session_path, alert: "This invitation has expired or was already used."
      return
    end

    account = @invitation.account

    # Check if already a member
    if account.users.where(identity: Current.identity, active: true).exists?
      @invitation.accept!
      redirect_to "/#{account.external_account_id}", notice: "You are already a member of this account."
      return
    end

    ActiveRecord::Base.transaction do
      # Deactivate any existing account membership
      Current.identity.users.where(active: true).find_each(&:deactivate)

      # Create user in target account
      account.users.create!(
        identity: Current.identity,
        name: Current.identity.email_address,
        role: :member,
        verified_at: Time.current
      )

      # Execute any pending recipe transfers
      PendingRecipeTransfer.execute_for(Current.identity, account)

      @invitation.accept!
    end

    redirect_to "/#{account.external_account_id}", notice: "Welcome! You've joined #{account.name}."
  end

  private

  def require_authenticated_identity
    return if Current.identity

    session[:return_to] = request.fullpath
    redirect_to new_session_path
  end

  def set_invitation
    @invitation = Invitation.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to new_session_path, alert: "Invitation not found."
  end
end

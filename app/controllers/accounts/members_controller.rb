class Accounts::MembersController < ApplicationController
  before_action :ensure_admin, only: :destroy

  def index
    @members = Current.account.users.active.includes(:identity).order(:name)
    @join_code = Current.account.join_code
    @dietary_profiles = Current.account.dietary_profiles.active.order(:name)
    @pending_invitations = Current.account.invitations.pending.order(created_at: :desc)
  end

  def destroy
    @member = Current.account.users.active.find(params[:id])

    if @member.owner?
      redirect_to members_path, alert: "Cannot remove the account owner."
      return
    end

    if @member == Current.user
      redirect_to members_path, alert: "You cannot remove yourself. Use the leave option instead."
      return
    end

    @member.deactivate
    redirect_to members_path, notice: "#{@member.name} has been removed from the account."
  end
end

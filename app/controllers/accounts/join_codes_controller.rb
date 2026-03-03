class Accounts::JoinCodesController < ApplicationController
  before_action :ensure_admin

  def update
    Current.account.join_code.reset
    redirect_to members_path, notice: "Join code has been regenerated."
  end
end

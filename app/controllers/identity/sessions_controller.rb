class Identity::SessionsController < ApplicationController
  disallow_account_scope
  allow_unauthorized_access

  def index
    @sessions = Current.identity.sessions.order(created_at: :desc)
    @current_session = Current.session
  end

  def destroy
    session = Current.identity.sessions.find(params[:id])

    if session == Current.session
      redirect_to identity_sessions_path, alert: "Cannot destroy your current session."
    else
      session.destroy
      redirect_to identity_sessions_path, notice: "Session terminated."
    end
  end
end

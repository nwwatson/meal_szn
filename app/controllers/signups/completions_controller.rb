class Signups::CompletionsController < ApplicationController
  disallow_account_scope
  skip_onboarding_redirect
  allow_unauthorized_access

  layout "public"

  before_action :require_authenticated_identity

  def new
    @signup = Signup.new(identity: Current.identity)
  end

  def create
    @signup = Signup.new(
      identity: Current.identity,
      full_name: params[:full_name]
    )

    if (account = @signup.complete)
      redirect_to "/#{account.external_account_id}", notice: "Welcome to your new account!"
    else
      flash.now[:alert] = @signup.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_authenticated_identity
    redirect_to new_session_path unless Current.identity
  end
end

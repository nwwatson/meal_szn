class SignupsController < ApplicationController
  include Authentication::ViaMagicLink

  disallow_account_scope
  skip_onboarding_redirect
  allow_unauthorized_access
  require_unauthenticated_access

  layout "public"

  rate_limit to: 10, within: 3.minutes, only: :create

  before_action :ensure_signups_allowed

  def new
  end

  def create
    @signup = Signup.new(email_address: params[:email_address])

    if @signup.create_identity
      redirect_to_session_magic_link(@signup.identity)
    else
      flash.now[:alert] = @signup.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def ensure_signups_allowed
    redirect_to new_session_path unless Account.accepting_signups?
  end
end

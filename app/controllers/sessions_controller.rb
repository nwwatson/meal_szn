class SessionsController < ApplicationController
  include Authentication::ViaMagicLink

  disallow_account_scope
  skip_onboarding_redirect
  allow_unauthorized_access
  require_unauthenticated_access only: [ :new, :create ]
  allow_unauthenticated_access only: :destroy

  layout "public"

  rate_limit to: 10, within: 3.minutes, only: :create

  def new
  end

  def create
    if (identity = Identity.find_by(email_address: params[:email_address]))
      sign_in(identity)
    elsif Account.accepting_signups?
      sign_up
    else
      redirect_to_fake_session_magic_link
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end

  private

  def sign_in(identity)
    identity.send_magic_link(purpose: :sign_in)
    redirect_to_session_magic_link(identity)
  end

  def sign_up
    signup = Signup.new(email_address: params[:email_address])
    if signup.create_identity
      redirect_to_session_magic_link(signup.identity)
    else
      flash.now[:alert] = signup.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end
end

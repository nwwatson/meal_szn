class OnboardingsController < ApplicationController
  include Authentication::ViaMagicLink

  disallow_account_scope
  skip_onboarding_redirect
  allow_unauthorized_access
  require_unauthenticated_access

  layout "public"

  rate_limit to: 10, within: 3.minutes, only: :create

  before_action :ensure_onboarding_available

  def new
  end

  def create
    @onboarding = Onboarding.new(email_address: params[:email_address])

    if @onboarding.create_identity
      redirect_to_session_magic_link(@onboarding.identity)
    else
      flash.now[:alert] = @onboarding.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def ensure_onboarding_available
    redirect_to new_session_path unless Account.requires_onboarding?
  end
end

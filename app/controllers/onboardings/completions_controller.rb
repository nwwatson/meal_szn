class Onboardings::CompletionsController < ApplicationController
  disallow_account_scope
  skip_onboarding_redirect
  allow_unauthorized_access

  layout "public"

  before_action :require_authenticated_identity
  before_action :ensure_onboarding_available

  def new
    @onboarding = Onboarding.new(identity: Current.identity)
  end

  def create
    @onboarding = Onboarding.new(
      identity: Current.identity,
      full_name: params[:full_name],
      organization_name: params[:organization_name]
    )

    if (account = @onboarding.complete)
      redirect_to "/#{account.external_account_id}", notice: "Welcome! Your organization is ready."
    else
      flash.now[:alert] = @onboarding.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_authenticated_identity
    redirect_to new_onboarding_path unless Current.identity
  end

  def ensure_onboarding_available
    redirect_to new_session_path unless Account.requires_onboarding?
  end
end

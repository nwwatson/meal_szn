class Sessions::MagicLinksController < ApplicationController
  include Authentication::ViaMagicLink

  disallow_account_scope
  skip_onboarding_redirect
  allow_unauthorized_access
  require_unauthenticated_access

  layout "public"

  rate_limit to: 10, within: 15.minutes, only: :create

  def show
    @email_address = email_address_pending_authentication
    redirect_to new_session_path unless @email_address
  end

  def create
    magic_link = find_valid_magic_link
    pending_email = email_address_pending_authentication

    if magic_link && secure_email_match?(magic_link.identity.email_address, pending_email)
      authenticate_with_magic_link(magic_link)
    else
      flash.now[:alert] = "Invalid or expired code"
      render :show, status: :unprocessable_entity
    end
  end

  private

  def find_valid_magic_link
    return unless params[:code].present?
    MagicLink.active.find_by(code: normalize_code(params[:code]))
  end

  def normalize_code(code)
    code.to_s.gsub(/[^A-Za-z0-9]/, "").upcase.tr("OIL", "011")
  end

  def secure_email_match?(email1, email2)
    ActiveSupport::SecurityUtils.secure_compare(email1.to_s.downcase, email2.to_s.downcase)
  end

  def authenticate_with_magic_link(magic_link)
    identity = magic_link.identity
    purpose = magic_link.purpose

    magic_link.destroy!
    clear_pending_authentication_token
    start_new_session_for(identity)

    case purpose
    when "sign_up"
      redirect_to new_signup_completion_path
    when "onboarding"
      redirect_to new_onboarding_completion_path
    else
      redirect_to return_url
    end
  end
end

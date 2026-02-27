module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :redirect_if_requires_onboarding
    before_action :set_account_from_request
    before_action :require_account
    before_action :require_authentication

    helper_method :signed_in?
  end

  class_methods do
    def require_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      before_action :redirect_authenticated_user, **options
    end

    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      before_action :resume_session_if_present, **options
    end

    def disallow_account_scope(**options)
      skip_before_action :set_account_from_request, **options
      skip_before_action :require_account, **options
    end

    def skip_onboarding_redirect(**options)
      skip_before_action :redirect_if_requires_onboarding, **options
    end
  end

  def signed_in?
    Current.session.present?
  end

  private

  # Redirect to onboarding when no accounts exist (first-boot scenario)
  def redirect_if_requires_onboarding
    redirect_to new_onboarding_path if Account.requires_onboarding?
  end

  def set_account_from_request
    Current.account = request.env["meal_szn.account"]
  end

  def require_account
    head :bad_request unless Current.account
  end

  def require_authentication
    resume_session || authenticate_by_bearer_token || request_authentication
  end

  def resume_session
    return false unless (session = find_session_from_cookie)
    return false if session.expired?
    return false unless session.validates_integrity?(request)

    Current.session = session
    session.refresh_activity!
    true
  end

  def resume_session_if_present
    resume_session
  end

  def find_session_from_cookie
    return unless (signed_id = cookies.signed[:session_token])
    Session.active.find_signed(signed_id)
  end

  def authenticate_by_bearer_token
    return false unless (token = request.headers["Authorization"]&.delete_prefix("Bearer "))

    identity, access_token = Identity.find_with_access_token(token, request.method)
    return false unless identity

    # Record token usage for audit trail
    access_token.record_usage!(request)

    Current.identity = identity
    # Set Current.user based on account context for API authorization
    Current.user = identity.users.find_by(account: Current.account, active: true) if Current.account
    true
  end

  def request_authentication
    store_return_url
    redirect_to new_session_path
  end

  def redirect_authenticated_user
    redirect_to default_account_url if signed_in?
  end

  def start_new_session_for(identity)
    session = identity.sessions.create!(
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )
    Current.session = session
    set_session_cookie(session)
  end

  def set_session_cookie(session)
    cookies.signed.permanent[:session_token] = {
      value: session.signed_id,
      httponly: true,
      same_site: :lax
    }
  end

  def terminate_session
    Current.session&.destroy
    cookies.delete(:session_token)
    Current.reset
  end

  def store_return_url
    session[:return_to] = request.fullpath if request.get? || request.head?
  end

  def return_url
    session.delete(:return_to) || default_account_url
  end

  def default_account_url
    account = Current.session&.identity&.accounts&.first
    account ? "#{account.slug}/" : account_root_path
  end
end

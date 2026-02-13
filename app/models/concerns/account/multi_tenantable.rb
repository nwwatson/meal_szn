module Account::MultiTenantable
  extend ActiveSupport::Concern

  class_methods do
    # Configure via environment variable: MULTI_TENANT=true
    # Single-tenant mode (default): Only one account allowed, first user becomes owner
    # Multi-tenant mode: Multiple accounts allowed, users can create new accounts
    mattr_accessor :multi_tenant, default: false

    def accepting_signups?
      multi_tenant || none?
    end

    # Returns true when this is a fresh install with no accounts yet
    # Used to trigger initial onboarding flow for the first user
    def requires_onboarding?
      !multi_tenant && none?
    end
  end
end

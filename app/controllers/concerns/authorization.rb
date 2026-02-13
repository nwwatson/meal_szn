module Authorization
  extend ActiveSupport::Concern

  included do
    before_action :ensure_can_access_account
  end

  class_methods do
    def allow_unauthorized_access(**options)
      skip_before_action :ensure_can_access_account, **options
    end

    def require_access_without_a_user(**options)
      skip_before_action :ensure_can_access_account, **options
      before_action :ensure_account_accessible, **options
    end
  end

  private

  def ensure_can_access_account
    return if Current.account&.active? && Current.user&.active?
    head :forbidden
  end

  def ensure_account_accessible
    return if Current.account && !Current.account.cancelled?
    head :forbidden
  end

  def ensure_admin
    head :forbidden unless Current.user&.admin?
  end

  def ensure_staff
    head :forbidden unless Current.identity&.staff?
  end
end

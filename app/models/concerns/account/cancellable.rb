module Account::Cancellable
  extend ActiveSupport::Concern

  included do
    has_one :cancellation, class_name: "Account::Cancellation", dependent: :destroy

    define_callbacks :cancel, :reactivate
  end

  def cancel(initiated_by: Current.user)
    return false unless cancellable? && active?

    with_lock do
      run_callbacks :cancel do
        create_cancellation!(user: initiated_by)
      end
    end

    true
  end

  def reactivate
    return false unless cancelled?

    with_lock do
      run_callbacks :reactivate do
        cancellation.destroy!
      end
    end

    true
  end

  def cancelled?
    cancellation.present?
  end

  def cancellable?
    Account.accepting_signups?
  end

  def active?
    !cancelled?
  end
end

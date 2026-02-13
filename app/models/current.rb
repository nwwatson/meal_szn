class Current < ActiveSupport::CurrentAttributes
  attribute :session, :identity, :user, :account

  def session=(session)
    super
    self.identity = session&.identity
  end

  def identity=(identity)
    super
    self.user = identity&.users&.find_by(account: account, active: true) if account
  end
end

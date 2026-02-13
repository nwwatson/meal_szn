module User::Role
  extend ActiveSupport::Concern

  included do
    enum :role, { owner: 0, admin: 1, member: 2, system: 3 }

    scope :owners, -> { active.where(role: :owner) }
    scope :admins, -> { active.where(role: [ :owner, :admin ]) }
    scope :members, -> { active.where(role: :member) }
  end

  def admin?
    owner? || read_attribute(:role) == "admin"
  end

  def can_change?(other)
    return true if self == other
    admin? && !other.owner?
  end

  def can_administer?(other)
    return false if self == other
    admin? && !other.owner?
  end

  def has_role_at_least?(target_role)
    role_value = self.class.roles[role]
    target_value = self.class.roles[target_role.to_s]
    return false unless role_value && target_value
    role_value <= target_value
  end
end

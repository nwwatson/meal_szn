class User < ApplicationRecord
  include User::Role
  include User::Accessor
  include User::Configurable

  belongs_to :account
  belongs_to :identity, optional: true  # optional for system users
  has_many :meal_plans, dependent: :destroy
  has_one :dietary_profile, dependent: :nullify
  has_many :sent_recipe_shares, class_name: "RecipeShare", foreign_key: :sender_id, dependent: :destroy

  validates :name, presence: true, length: { maximum: 240 }

  before_create :generate_id

  scope :active, -> { where(active: true).where.not(role: :system) }

  def verified?
    verified_at.present?
  end

  def verify
    update!(verified_at: Time.current)
  end

  def deactivate
    transaction do
      # Terminate all sessions for this user's identity in this account
      terminate_sessions
      update!(active: false, identity: nil)
    end
  end

  def setup?
    name.present? && name != identity&.email_address
  end

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end

  def terminate_sessions
    return unless identity
    identity.sessions.destroy_all
  end
end

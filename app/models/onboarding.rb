require "zlib"

class Onboarding
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations::Callbacks

  class RaceConditionError < StandardError; end

  attribute :email_address, :string
  attribute :full_name, :string
  attribute :organization_name, :string
  attribute :identity

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, on: :identity_creation
  validates :full_name, presence: true, length: { maximum: 240 }, on: :completion
  validates :organization_name, presence: true, length: { maximum: 240 }, on: :completion
  validates :identity, presence: true, on: :completion

  before_validation :normalize_email_address

  def create_identity
    return false unless valid?(:identity_creation)

    self.identity = Identity.find_or_create_by!(email_address: email_address)
    identity.send_magic_link(purpose: :onboarding)
    true
  end

  def complete
    return false unless valid?(:completion)
    return false unless Account.requires_onboarding?

    ActiveRecord::Base.transaction do
      # Double-check after starting transaction
      unless Account.none?
        errors.add(:base, "Another user has already completed onboarding")
        raise ActiveRecord::Rollback
      end

      # Mark identity as staff (global privilege)
      identity.update!(staff: true)

      # Create account with provided organization name
      account = Account.create!(name: organization_name)

      # Create system user (for automated actions, imports, scheduled jobs)
      account.users.create!(
        name: "System",
        role: :system
      )

      # Create owner user
      account.users.create!(
        identity: identity,
        name: full_name,
        role: :owner,
        verified_at: Time.current
      )

      account
    end
  end

  private

  def normalize_email_address
    self.email_address = email_address&.strip&.downcase
  end
end

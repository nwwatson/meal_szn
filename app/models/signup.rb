class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations::Callbacks

  ACCOUNT_NAME_MAX_LENGTH = 240

  attribute :email_address, :string
  attribute :full_name, :string
  attribute :identity

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, on: :identity_creation
  validates :full_name, presence: true, length: { maximum: 240 }, on: :completion
  validates :identity, presence: true, on: :completion
  validate :identity_does_not_have_account, on: :completion

  before_validation :normalize_email_address

  def create_identity
    return false unless valid?(:identity_creation)

    self.identity = Identity.find_or_create_by!(email_address: email_address)
    identity.send_magic_link(purpose: :sign_up)
    true
  end

  def complete
    return false unless valid?(:completion)

    # Cap account name length to prevent overflow
    account_name = "#{full_name}'s Account".truncate(ACCOUNT_NAME_MAX_LENGTH)

    account = Account.create!(name: account_name)

    # Create system user
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

  private

  def normalize_email_address
    self.email_address = email_address&.strip&.downcase
  end

  # Prevent duplicate account creation for same identity
  def identity_does_not_have_account
    return unless identity
    return unless Account.multi_tenant  # Only check in multi-tenant mode

    if identity.accounts.exists?
      errors.add(:base, "You already have an account. Please sign in instead.")
    end
  end
end

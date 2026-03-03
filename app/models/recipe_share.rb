class RecipeShare < ApplicationRecord
  EXPIRATION_TIME = 30.days
  TOKEN_LENGTH = 24

  belongs_to :recipe
  belongs_to :sender, class_name: "User"
  belongs_to :recipient_user, class_name: "User", optional: true

  enum :status, { pending: 0, accepted: 1, declined: 2 }

  validates :recipient_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  normalizes :recipient_email, with: ->(email) { email.strip.downcase }

  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create
  before_create :generate_id

  scope :active, -> { pending.where("expires_at > ?", Time.current) }
  scope :by_sender, ->(user) { where(sender: user) }

  def expired?
    expires_at <= Time.current
  end

  def redeemable?
    pending? && !expired?
  end

  def accept!(recipient_user:)
    update!(
      status: :accepted,
      accepted_at: Time.current,
      recipient_user: recipient_user
    )
  end

  def decline!
    update!(status: :declined)
  end

  def sender_name
    sender.name
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(TOKEN_LENGTH)
  end

  def set_expiration
    self.expires_at ||= EXPIRATION_TIME.from_now
  end

  def generate_id
    self.id ||= SecureRandom.uuid
  end
end

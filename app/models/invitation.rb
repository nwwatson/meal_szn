class Invitation < ApplicationRecord
  EXPIRATION_TIME = 7.days
  TOKEN_LENGTH = 32

  belongs_to :account
  belongs_to :invited_by, class_name: "User"

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  before_create :generate_id
  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  scope :accepted, -> { where.not(accepted_at: nil) }

  def expired?
    expires_at <= Time.current
  end

  def accepted?
    accepted_at.present?
  end

  def redeemable?
    !accepted? && !expired?
  end

  def accept!
    update!(accepted_at: Time.current)
  end

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(TOKEN_LENGTH)
  end

  def set_expiration
    self.expires_at ||= EXPIRATION_TIME.from_now
  end
end

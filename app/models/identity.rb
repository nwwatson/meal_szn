class Identity < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :access_tokens, class_name: "Identity::AccessToken", dependent: :destroy
  has_many :users, dependent: :nullify
  has_many :accounts, through: :users

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  before_create :generate_id

  # Find identity that has a valid access token for the given HTTP method
  # Returns [identity, access_token] tuple for usage tracking
  def self.find_by_permissable_access_token(token, http_method)
    access_token = Identity::AccessToken.active.find_by(token: token)
    return nil unless access_token&.permits?(http_method)
    access_token.identity
  end

  # Alternative method that returns token for usage tracking
  def self.find_with_access_token(token, http_method)
    access_token = Identity::AccessToken.active.find_by(token: token)
    return [ nil, nil ] unless access_token&.permits?(http_method)
    [ access_token.identity, access_token ]
  end

  def send_magic_link(purpose: :sign_in)
    magic_link = magic_links.create!(purpose: purpose)
    mailer_method = "#{purpose}_code"
    MagicLinkMailer.public_send(mailer_method, magic_link).deliver_later
    magic_link
  end

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end
end

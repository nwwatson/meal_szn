class MagicLink < ApplicationRecord
  CODE_LENGTH = 6
  EXPIRATION_TIME = 15.minutes

  belongs_to :identity

  enum :purpose, { sign_in: 0, sign_up: 1, onboarding: 2 }

  validates :code, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :purpose, presence: true

  before_create :generate_id
  before_validation :generate_code_and_expiration, on: :create

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :stale, -> { where("expires_at <= ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def consume(submitted_code)
    return false if expired?
    return false unless ActiveSupport::SecurityUtils.secure_compare(code.upcase, normalize_code(submitted_code))
    destroy
    true
  end

  def self.cleanup
    stale.delete_all
  end

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end

  def generate_code_and_expiration
    self.code ||= generate_unique_code
    self.expires_at ||= EXPIRATION_TIME.from_now
  end

  SAFE_CHARS = (("A".."Z").to_a + ("0".."9").to_a) - %w[O I L]

  def generate_unique_code
    loop do
      code = Array.new(CODE_LENGTH) { SAFE_CHARS.sample(random: SecureRandom) }.join
      break code unless MagicLink.exists?(code: code)
    end
  end

  def normalize_code(code)
    code.to_s.gsub(/[^A-Za-z0-9]/, "").upcase.tr("OIL", "011")  # Strip formatting, handle confused characters
  end
end

class Session < ApplicationRecord
  EXPIRATION_TIME = 2.weeks
  ACTIVITY_REFRESH_INTERVAL = 1.hour
  IP_CHANGE_POLICY = :warn  # :warn, :block, or :ignore

  belongs_to :identity

  validates :ip_address, presence: true
  validates :user_agent, presence: true
  validates :expires_at, presence: true

  before_create :generate_id
  before_validation :set_expiration, on: :create

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def refresh_activity!
    return if last_active_at && last_active_at > ACTIVITY_REFRESH_INTERVAL.ago
    update!(last_active_at: Time.current, expires_at: EXPIRATION_TIME.from_now)
  end

  # Validates session integrity against current request
  # Returns true if valid, false if suspicious
  def validates_integrity?(request)
    case IP_CHANGE_POLICY
    when :block
      return false if ip_address != request.remote_ip
    when :warn
      if ip_address != request.remote_ip
        Rails.logger.warn "[Session] IP change detected for session #{id}: #{ip_address} -> #{request.remote_ip}"
      end
    end
    true
  end

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end

  def set_expiration
    self.expires_at ||= EXPIRATION_TIME.from_now
    self.last_active_at ||= Time.current
  end
end

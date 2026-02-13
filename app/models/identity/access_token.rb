class Identity::AccessToken < ApplicationRecord
  self.table_name = "access_tokens"

  belongs_to :identity

  has_secure_token :token

  enum :permission, { read: 0, write: 1 }

  validates :name, presence: true
  validates :permission, presence: true

  before_create :generate_id

  scope :active, -> {
    where(revoked_at: nil)
      .where("expires_at IS NULL OR expires_at > ?", Time.current)
  }
  scope :expired, -> { where("expires_at IS NOT NULL AND expires_at <= ?", Time.current) }
  scope :revoked, -> { where.not(revoked_at: nil) }

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def active?
    !expired? && !revoked?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def can_read? = read? || write?

  def can_write? = write?

  def permits?(http_method)
    return false unless active?
    return true if write?
    %w[GET HEAD OPTIONS].include?(http_method.to_s.upcase)
  end

  def record_usage!(request)
    update!(last_used_at: Time.current, last_used_ip: request.remote_ip)
  end

  # Returns masked token for display (e.g., "abc...xyz")
  def masked_token
    return nil if token.blank?
    "#{token[0..3]}...#{token[-4..]}"
  end

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end
end

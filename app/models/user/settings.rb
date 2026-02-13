class User::Settings < ApplicationRecord
  self.table_name = "user_settings"

  belongs_to :user

  enum :email_frequency, { never: 0, every_4_hours: 1, daily: 2, weekly: 3 }
  enum :unit_system, { standard: 0, metric: 1 }

  before_create :generate_id

  def timezone
    super.presence || "UTC"
  end

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end
end

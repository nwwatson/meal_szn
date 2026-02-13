class Account::Cancellation < ApplicationRecord
  self.table_name = "account_cancellations"

  belongs_to :account
  belongs_to :user  # initiated_by

  validates :account_id, uniqueness: true

  before_create :generate_id

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end
end

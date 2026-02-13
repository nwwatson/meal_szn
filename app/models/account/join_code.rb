class Account::JoinCode < ApplicationRecord
  self.table_name = "account_join_codes"

  CODE_LENGTH = 12
  USAGE_LIMIT_MAX = 10_000_000_000

  belongs_to :account

  validates :code, presence: true, uniqueness: true
  validates :usage_limit, numericality: { greater_than: 0, less_than_or_equal_to: USAGE_LIMIT_MAX }

  before_create :generate_id
  before_validation :generate_code, on: :create

  scope :active, -> { where("usage_count < usage_limit") }

  def active?
    usage_count < usage_limit
  end

  def redeem_if
    return false unless active?

    with_lock do
      return false unless active?
      return false unless yield

      increment!(:usage_count)
      true
    end
  end

  def reset
    update!(
      code: generate_code_string,
      usage_count: 0
    )
  end

  def formatted_code
    code.scan(/.{4}/).join("-")
  end

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end

  def generate_code
    self.code ||= generate_code_string
  end

  def generate_code_string
    loop do
      code = SecureRandom.base58(CODE_LENGTH)
      break code unless Account::JoinCode.exists?(code: code)
    end
  end
end

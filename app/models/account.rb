class Account < ApplicationRecord
  include Account::Cancellable
  include Account::MultiTenantable

  has_many :users, dependent: :destroy
  has_many :identities, through: :users
  has_many :accesses, dependent: :destroy
  has_one :join_code, class_name: "Account::JoinCode", dependent: :destroy
  has_many :recipes, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :meal_plans, dependent: :destroy
  has_many :dietary_profiles, dependent: :destroy
  has_many :ai_task_statuses, dependent: :destroy
  has_many :ai_request_metrics, dependent: :destroy

  validates :name, presence: true
  validates :external_account_id, presence: true, uniqueness: true

  before_create :generate_id
  before_validation :generate_external_account_id, on: :create
  after_create :create_join_code

  scope :not_cancelled, -> { left_joins(:cancellation).where(account_cancellations: { id: nil }) }

  def slug
    "/#{external_account_id}"
  end

  def owner
    users.find_by(role: :owner)
  end

  def system_user
    users.find_by(role: :system)
  end

  def self.create_with_owner(name:, owner_identity:, owner_name:)
    transaction do
      account = create!(name: name)

      # Create system user
      account.users.create!(
        name: "System",
        role: :system
      )

      # Create owner user
      account.users.create!(
        identity: owner_identity,
        name: owner_name,
        role: :owner,
        verified_at: Time.current
      )

      account
    end
  end

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end

  def generate_external_account_id
    self.external_account_id ||= loop do
      id = SecureRandom.random_number(10_000_000..99_999_999)
      break id unless Account.exists?(external_account_id: id)
    end
  end

  def create_join_code
    build_join_code.save!
  end
end

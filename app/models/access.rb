class Access < ApplicationRecord
  belongs_to :account
  belongs_to :user
  belongs_to :entity, polymorphic: true

  enum :involvement, { access_only: 0, watching: 1 }

  validates :user_id, uniqueness: { scope: [ :entity_type, :entity_id ] }

  before_create :generate_id

  scope :watching, -> { where(involvement: :watching) }
  scope :for_entity_type, ->(type) { where(entity_type: type) }

  def self.grant_to(users, entity:)
    users.each do |user|
      find_or_create_by!(user: user, account: user.account, entity: entity)
    end
  end

  def self.revoke_from(users)
    where(user: users).destroy_all
  end

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end
end

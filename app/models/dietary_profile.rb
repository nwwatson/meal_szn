class DietaryProfile < ApplicationRecord
  include Identifiable

  belongs_to :account
  belongs_to :user, optional: true
  has_many :meal_plan_participants, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :daily_calories_target, numericality: { greater_than: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }

  def diet
    DietRegistry.find_by_name(diet_name) if diet_name.present?
  end

  def macro_targets
    DietRegistry.macro_targets_for(diet_name, daily_calories_target)
  end

  def linked_to_user?
    user_id.present?
  end

  def to_api_response
    {
      id: id,
      name: name,
      diet_name: diet_name,
      daily_calories_target: daily_calories_target,
      macro_targets: macro_targets,
      user_id: user_id,
      active: active,
      created_at: created_at,
      updated_at: updated_at
    }
  end
end

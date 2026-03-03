class ShoppingList < ApplicationRecord
  include Identifiable

  belongs_to :account
  belongs_to :user
  belongs_to :meal_plan
  has_many :items, class_name: "ShoppingListItem", dependent: :destroy

  def all_checked?
    items.any? && items.unchecked.none?
  end

  def checked_count
    items.checked.count
  end

  def total_count
    items.count
  end

  def to_api_response
    {
      id: id,
      name: name,
      meal_plan_id: meal_plan_id,
      checked_count: checked_count,
      total_count: total_count,
      all_checked: all_checked?,
      items: items.alphabetical.map(&:to_api_response),
      created_at: created_at,
      updated_at: updated_at
    }
  end
end

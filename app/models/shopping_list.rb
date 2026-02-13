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
end

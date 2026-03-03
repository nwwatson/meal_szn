class ShoppingListItem < ApplicationRecord
  include Identifiable

  belongs_to :shopping_list

  validates :name, presence: true

  scope :unchecked, -> { where(checked: false) }
  scope :checked, -> { where(checked: true) }
  scope :alphabetical, -> { order(:name) }

  def display_text
    parts = []
    parts << quantity if quantity.present?
    parts << unit if unit.present?
    parts << name
    parts.join(" ")
  end

  def to_api_response
    {
      id: id,
      name: name,
      quantity: quantity,
      unit: unit,
      checked: checked,
      display_text: display_text
    }
  end
end

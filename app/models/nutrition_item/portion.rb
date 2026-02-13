class NutritionItem::Portion < ApplicationRecord
  include Identifiable

  self.table_name = "nutrition_item_portions"

  belongs_to :nutrition_item

  validates :description, presence: true
  validates :gram_weight, presence: true, numericality: { greater_than: 0 }

  def unit_matches?(unit_string)
    return false if unit_string.blank?

    normalized = unit_string.to_s.downcase.strip
    unit&.downcase&.strip == normalized ||
      description&.downcase&.include?(normalized)
  end
end

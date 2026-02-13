class NutritionItem::Alias < ApplicationRecord
  include Identifiable

  self.table_name = "nutrition_item_aliases"

  belongs_to :nutrition_item

  validates :name, presence: true, uniqueness: true

  before_validation :normalize_name

  private

  def normalize_name
    self.name = NutritionItem.normalize_name(name) if name.present?
  end
end

class NutritionItem < ApplicationRecord
  include Identifiable

  has_many :aliases, class_name: "NutritionItem::Alias", dependent: :destroy
  has_many :portions, class_name: "NutritionItem::Portion", dependent: :destroy
  has_many :ingredients, dependent: :nullify

  validates :fdc_id, presence: true, uniqueness: true
  validates :description, presence: true

  def self.normalize_name(name)
    name.to_s
      .downcase
      .strip
      .gsub(/\s*\(.*?\)\s*/, " ")  # remove parentheticals
      .gsub(/,\s*$/, "")            # remove trailing commas
      .gsub(/\s+/, " ")             # collapse whitespace
      .strip
  end

  def self.find_by_name(name)
    normalized = normalize_name(name)
    NutritionItem::Alias.find_by(name: normalized)&.nutrition_item
  end

  def grams_for(quantity_decimal, unit)
    return nil if quantity_decimal.nil?

    # Try direct weight conversion first
    weight_grams = Nutrition::UnitConverter.to_grams(quantity_decimal, unit)
    return weight_grams if weight_grams

    return nil if unit.blank?

    # Try USDA portions (lazy-load if needed)
    ensure_portions_loaded!

    matching_portion = portions.find { |p| p.unit_matches?(unit) }
    return nil unless matching_portion

    portion_amount = matching_portion.amount || 1.0
    (quantity_decimal / portion_amount) * matching_portion.gram_weight
  end

  private

  def ensure_portions_loaded!
    return if portions_fetched?

    Nutrition::UsdaPortionFetcher.new(self).fetch
  end
end

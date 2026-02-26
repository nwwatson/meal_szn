class Ingredient < ApplicationRecord
  include Identifiable

  STANDARD_UNITS = %w[cups tbsp tsp oz lb fl\ oz quart gallon pint].freeze
  METRIC_UNITS = %w[ml l g kg].freeze
  UNIVERSAL_UNITS = %w[pinch dash whole slice clove piece].freeze
  ALL_UNITS = (STANDARD_UNITS + METRIC_UNITS + UNIVERSAL_UNITS).freeze
  UNITS_PATTERN = Regexp.union(ALL_UNITS).freeze

  def self.grouped_unit_options(unit_system = "standard")
    if unit_system == "metric"
      { "Metric" => METRIC_UNITS, "Standard" => STANDARD_UNITS, "Universal" => UNIVERSAL_UNITS }
    else
      { "Standard" => STANDARD_UNITS, "Metric" => METRIC_UNITS, "Universal" => UNIVERSAL_UNITS }
    end
  end

  belongs_to :recipe
  belongs_to :nutrition_item, optional: true

  validates :name, presence: true

  def nutrition_resolved?
    nutrition_item_id.present?
  end

  def to_api_response
    {
      name: name,
      quantity: quantity,
      unit: unit
    }
  end

  def display_text
    parts = []
    parts << quantity if quantity.present?
    parts << unit if unit.present?
    parts << name
    parts.join(" ")
  end
end

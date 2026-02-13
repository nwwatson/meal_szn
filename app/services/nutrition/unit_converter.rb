module Nutrition
  class UnitConverter
    WEIGHT_TO_GRAMS = {
      "g" => 1.0,
      "gram" => 1.0,
      "grams" => 1.0,
      "kg" => 1000.0,
      "kilogram" => 1000.0,
      "kilograms" => 1000.0,
      "oz" => 28.35,
      "ounce" => 28.35,
      "ounces" => 28.35,
      "lb" => 453.59,
      "lbs" => 453.59,
      "pound" => 453.59,
      "pounds" => 453.59
    }.freeze

    def self.to_grams(quantity, unit)
      return nil if unit.blank?

      factor = WEIGHT_TO_GRAMS[unit.to_s.downcase.strip]
      return nil unless factor

      quantity * factor
    end

    def self.weight_unit?(unit)
      WEIGHT_TO_GRAMS.key?(unit.to_s.downcase.strip)
    end
  end
end

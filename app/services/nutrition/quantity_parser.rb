module Nutrition
  class QuantityParser
    FRACTION_MAP = {
      "¼" => 0.25, "½" => 0.5, "¾" => 0.75,
      "⅓" => 0.333, "⅔" => 0.667,
      "⅛" => 0.125, "⅜" => 0.375, "⅝" => 0.625, "⅞" => 0.875
    }.freeze

    def self.parse(quantity_string)
      new(quantity_string).parse
    end

    def initialize(quantity_string)
      @raw = quantity_string.to_s.strip
    end

    def parse
      return nil if @raw.blank?

      # Unicode fractions
      FRACTION_MAP.each do |char, value|
        if @raw.include?(char)
          whole = @raw.gsub(char, "").strip
          return (whole.present? ? whole.to_f : 0) + value
        end
      end

      # Mixed number: "1 1/2"
      if @raw.match?(/\A\d+\s+\d+\/\d+\z/)
        parts = @raw.split(/\s+/)
        whole = parts[0].to_f
        fraction_parts = parts[1].split("/")
        return whole + (fraction_parts[0].to_f / fraction_parts[1].to_f)
      end

      # Simple fraction: "1/2"
      if @raw.match?(/\A\d+\/\d+\z/)
        parts = @raw.split("/")
        return parts[0].to_f / parts[1].to_f
      end

      # Decimal or integer: "4", "2.5"
      return @raw.to_f if @raw.match?(/\A\d+(\.\d+)?\z/)

      nil
    end
  end
end

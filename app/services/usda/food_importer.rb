module Usda
  class FoodImporter
    NUTRIENT_IDS = {
      1008 => :calories,
      1004 => :fat,
      1003 => :protein,
      1005 => :carbs,
      1079 => :fiber,
      1093 => :sodium,
      1092 => :potassium,
      1090 => :magnesium
    }.freeze

    def initialize(api_data)
      @data = api_data
    end

    def import
      fdc_id = @data["fdcId"]
      existing = NutritionItem.find_by(fdc_id: fdc_id)
      return existing if existing

      nutrients = extract_nutrients

      NutritionItem.create!(
        fdc_id: fdc_id,
        description: @data["description"],
        calories: nutrients[:calories]&.to_i,
        fat: nutrients[:fat],
        protein: nutrients[:protein],
        carbs: nutrients[:carbs],
        fiber: nutrients[:fiber],
        sodium: nutrients[:sodium]&.to_i,
        potassium: nutrients[:potassium]&.to_i,
        magnesium: nutrients[:magnesium]&.to_i
      )
    end

    private

    def extract_nutrients
      nutrients = {}
      nutrient_list = @data["foodNutrients"] || []

      nutrient_list.each do |fn|
        nutrient_id = fn.dig("nutrient", "id") || fn["nutrientId"]
        attribute = NUTRIENT_IDS[nutrient_id]
        next unless attribute

        nutrients[attribute] = fn["amount"] || fn["value"]
      end

      nutrients
    end
  end
end

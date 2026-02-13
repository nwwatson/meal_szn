module Nutrition
  class UsdaPortionFetcher
    def initialize(nutrition_item)
      @item = nutrition_item
    end

    def fetch
      return if @item.portions_fetched?

      client = Usda::Client.new
      data = client.food(@item.fdc_id)
      food_portions = data["foodPortions"] || []

      food_portions.each do |fp|
        @item.portions.create!(
          description: portion_description(fp),
          amount: fp["amount"],
          unit: extract_unit(fp),
          gram_weight: fp["gramWeight"]
        )
      end

      @item.update!(portions_fetched: true)
    rescue Usda::Client::ApiError => e
      Rails.logger.warn("Failed to fetch portions for NutritionItem #{@item.id}: #{e.message}")
    end

    private

    def portion_description(fp)
      parts = []
      parts << fp["amount"].to_s if fp["amount"].present?
      parts << fp["modifier"] if fp["modifier"].present?
      parts << fp["measureUnit"]&.dig("name") if fp.dig("measureUnit", "name").present?
      parts.join(" ").presence || "unknown"
    end

    def extract_unit(fp)
      fp["modifier"]&.downcase || fp.dig("measureUnit", "name")&.downcase
    end
  end
end

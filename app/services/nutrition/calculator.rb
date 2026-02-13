module Nutrition
  class Calculator
    Result = Struct.new(:success, :nutrition_data, :unresolved_ingredients, keyword_init: true) do
      def success? = success
    end

    SKIPPABLE_UNITS = %w[pinch dash].freeze

    def initialize(recipe)
      @recipe = recipe
    end

    def calculate
      unresolved = []
      totals = { calories: 0.0, fat: 0.0, protein: 0.0, carbs: 0.0, fiber: 0.0,
                 sodium: 0.0, potassium: 0.0, magnesium: 0.0 }

      @recipe.ingredients.each do |ingredient|
        item = resolve_nutrition_item(ingredient)

        unless item
          unresolved << ingredient
          next
        end

        quantity = QuantityParser.parse(ingredient.quantity)

        # Skip ingredients we can't quantify (pinch, dash, or nil quantity)
        if SKIPPABLE_UNITS.include?(ingredient.unit&.downcase) || quantity.nil?
          next
        end

        grams = item.grams_for(quantity, ingredient.unit)
        next unless grams

        factor = grams / 100.0
        totals[:calories] += (item.calories || 0) * factor
        totals[:fat] += (item.fat || 0) * factor
        totals[:protein] += (item.protein || 0) * factor
        totals[:carbs] += (item.carbs || 0) * factor
        totals[:fiber] += (item.fiber || 0) * factor
        totals[:sodium] += (item.sodium || 0) * factor
        totals[:potassium] += (item.potassium || 0) * factor
        totals[:magnesium] += (item.magnesium || 0) * factor
      end

      return Result.new(success: false, unresolved_ingredients: unresolved) if unresolved.any?

      servings = [ @recipe.servings || 1, 1 ].max
      per_serving = totals.transform_values { |v| v / servings }

      Result.new(
        success: true,
        nutrition_data: {
          calories: per_serving[:calories].round,
          fat: per_serving[:fat].round(1),
          protein: per_serving[:protein].round(1),
          carbs: per_serving[:carbs].round(1),
          fiber: per_serving[:fiber].round(1),
          sodium: per_serving[:sodium].round,
          potassium: per_serving[:potassium].round,
          magnesium: per_serving[:magnesium].round,
          auto_calculated: true
        }
      )
    end

    private

    def resolve_nutrition_item(ingredient)
      # Use linked item if present
      return ingredient.nutrition_item if ingredient.nutrition_item_id.present?

      # Try alias lookup
      item = NutritionItem.find_by_name(ingredient.name)
      if item
        ingredient.update_columns(nutrition_item_id: item.id)
        return item
      end

      nil
    end
  end
end

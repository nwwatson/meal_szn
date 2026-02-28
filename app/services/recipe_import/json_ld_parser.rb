# frozen_string_literal: true

require "nokogiri"
require "json"

module RecipeImport
  class JsonLdParser
    def initialize(html)
      @html = html
    end

    # Returns a normalized recipe hash or nil if no Recipe JSON-LD found
    def parse
      recipe_data = extract_recipe_json_ld
      return nil unless recipe_data

      normalize(recipe_data)
    end

    private

    def extract_recipe_json_ld
      doc = Nokogiri::HTML(@html)
      doc.css('script[type="application/ld+json"]').each do |script|
        data = safe_parse_json(script.text)
        next unless data

        recipe = find_recipe(data)
        return recipe if recipe
      end

      nil
    end

    def safe_parse_json(text)
      JSON.parse(text)
    rescue JSON::ParserError
      nil
    end

    def find_recipe(data)
      case data
      when Hash
        return data if recipe_type?(data)
        # Check @graph arrays
        if data["@graph"].is_a?(Array)
          data["@graph"].each do |item|
            return item if recipe_type?(item)
          end
        end
      when Array
        data.each do |item|
          result = find_recipe(item)
          return result if result
        end
      end

      nil
    end

    def recipe_type?(item)
      return false unless item.is_a?(Hash)
      type = item["@type"]
      type == "Recipe" || (type.is_a?(Array) && type.include?("Recipe"))
    end

    def normalize(data)
      {
        title: data["name"].to_s.strip,
        description: extract_text(data["description"]),
        servings: parse_yield(data["recipeYield"]),
        prep_time: parse_duration(data["prepTime"]),
        cook_time: parse_duration(data["cookTime"]),
        ingredients: parse_ingredients(data["recipeIngredient"]),
        instructions: parse_instructions(data["recipeInstructions"]),
        nutrition: parse_nutrition(data["nutrition"]),
        image_url: extract_image_url(data["image"]),
        source: data["url"] || data["mainEntityOfPage"]
      }.compact
    end

    def extract_text(value)
      case value
      when String then value.strip
      when Array then value.map(&:to_s).join(" ").strip
      end
    end

    def parse_yield(value)
      case value
      when Integer then value
      when String then value[/\d+/]&.to_i
      when Array then value.first.to_s[/\d+/]&.to_i
      end
    end

    def parse_duration(iso8601)
      return nil unless iso8601.is_a?(String)
      match = iso8601.match(/PT(?:(\d+)H)?(?:(\d+)M)?/)
      return nil unless match
      hours = (match[1] || 0).to_i
      minutes = (match[2] || 0).to_i
      hours * 60 + minutes
    end

    def parse_ingredients(list)
      return [] unless list.is_a?(Array)
      list.filter_map do |item|
        text = item.is_a?(String) ? item : item.to_s
        text.strip.presence
      end
    end

    def parse_instructions(list)
      return [] unless list.is_a?(Array)
      list.filter_map.with_index(1) do |item, index|
        text = case item
        when String then item
        when Hash then item["text"]
        end
        next unless text.present?
        { step_number: index, instruction: text.strip }
      end
    end

    def parse_nutrition(data)
      return nil unless data.is_a?(Hash)
      {
        calories: extract_number(data["calories"]),
        fat: extract_number(data["fatContent"]),
        protein: extract_number(data["proteinContent"]),
        carbs: extract_number(data["carbohydrateContent"]),
        fiber: extract_number(data["fiberContent"]),
        sodium: extract_number(data["sodiumContent"])
      }.compact.presence
    end

    def extract_number(value)
      return nil unless value
      value.to_s[/[\d.]+/]&.to_f&.round(1)
    end

    def extract_image_url(value)
      case value
      when String then value.strip.presence
      when Hash then value["url"]&.to_s&.strip&.presence
      when Array then extract_image_url(value.first)
      end
    end
  end
end

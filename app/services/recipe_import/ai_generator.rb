# frozen_string_literal: true

module RecipeImport
  class AiGenerator
    class GenerationError < StandardError; end

    RECIPE_TOOL = RecipeImport::AiExtractor::RECIPE_TOOL

    def initialize(description, diet_name: nil, ai_client: nil)
      @description = description
      @diet_name = diet_name
      @ai_client = ai_client || Ai::Client.new
    end

    def generate
      result = @ai_client.chat_with_tools(
        messages: [ { role: "user", content: user_prompt } ],
        tools: [ RECIPE_TOOL ],
        system: system_prompt,
        max_tokens: 4096,
        feature: "recipe_quick_entry"
      )

      normalize(result[:input])
    end

    private

    def system_prompt
      prompt = <<~PROMPT
        You are an expert chef and recipe creator. Given a brief description of a dish,
        generate a complete, detailed recipe with accurate ingredient quantities,
        clear step-by-step instructions, and estimated nutrition data per serving.
        Use the provided tool to return the structured recipe data.
        Be specific with quantities (e.g. "2 tablespoons butter" not just "butter").
        Include realistic prep and cook times.
        Estimate nutrition values per serving as accurately as possible.
      PROMPT

      if @diet_name.present?
        prompt += "\nIMPORTANT: This recipe must be appropriate for a #{@diet_name} diet. " \
                  "Choose ingredients and quantities that fit this dietary approach."
      end

      prompt
    end

    def user_prompt
      "Create a recipe for: #{@description}"
    end

    def normalize(input)
      instructions = (input["instructions"] || []).map.with_index(1) do |text, i|
        { step_number: i, instruction: text }
      end

      nutrition = {
        calories: input["calories"],
        fat: input["fat"],
        protein: input["protein"],
        carbs: input["carbs"],
        fiber: input["fiber"]
      }.compact.presence

      {
        title: input["title"],
        description: input["description"],
        servings: input["servings"],
        prep_time: input["prep_time"],
        cook_time: input["cook_time"],
        ingredients: input["ingredients"] || [],
        instructions: instructions,
        nutrition: nutrition
      }.compact
    end
  end
end

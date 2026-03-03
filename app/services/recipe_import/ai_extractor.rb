# frozen_string_literal: true

module RecipeImport
  class AiExtractor
    include RecipeImport::Normalizer

    SYSTEM_PROMPT = <<~PROMPT
      You are a recipe extraction assistant. Given the text content of a web page,
      extract the recipe information and return it using the provided tool.
      If the page does not contain a recipe, return empty values.
      For ingredients, include the full text as written (e.g. "2 cups almond flour").
      For instructions, extract each step as a separate item.
    PROMPT

    RECIPE_TOOL = {
      name: "extract_recipe",
      description: "Extract structured recipe data from page content",
      input_schema: {
        type: "object",
        properties: {
          title: { type: "string", description: "Recipe title" },
          description: { type: "string", description: "Brief recipe description" },
          servings: { type: "integer", description: "Number of servings" },
          prep_time: { type: "integer", description: "Prep time in minutes" },
          cook_time: { type: "integer", description: "Cook time in minutes" },
          ingredients: {
            type: "array",
            items: { type: "string" },
            description: "List of ingredients with quantities"
          },
          instructions: {
            type: "array",
            items: { type: "string" },
            description: "Ordered list of cooking steps"
          },
          calories: { type: "number", description: "Calories per serving" },
          fat: { type: "number", description: "Fat grams per serving" },
          protein: { type: "number", description: "Protein grams per serving" },
          carbs: { type: "number", description: "Carbs grams per serving" },
          fiber: { type: "number", description: "Fiber grams per serving" }
        },
        required: [ "title", "ingredients", "instructions" ]
      }
    }.freeze

    def initialize(page_text, ai_client: nil)
      @page_text = page_text
      @ai_client = ai_client || Ai::Client.new
    end

    def extract
      # Truncate page text to avoid token limits
      truncated = @page_text[0, 12_000]

      result = @ai_client.chat_with_tools(
        messages: [ { role: "user", content: "Extract the recipe from this page:\n\n#{truncated}" } ],
        tools: [ RECIPE_TOOL ],
        system: SYSTEM_PROMPT,
        max_tokens: 4096,
        feature: "recipe_import"
      )

      normalize(result[:input])
    end
  end
end

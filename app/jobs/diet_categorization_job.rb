# frozen_string_literal: true

class DietCategorizationJob < AiBaseJob
  TOOL_NAME = "diet_scores"

  private

  def execute(recipe_id:)
    recipe = Recipe.includes(:ingredients, :nutrition_data).find(recipe_id)

    # If nutrition data exists, use the deterministic categorizer
    if recipe.nutrition_data&.calories&.positive?
      scores = DietCategorizer.new(recipe).categorize!
      return { recipe_id: recipe.id, scores: scores, method: "macro_analysis" }
    end

    # AI fallback: infer diet compatibility from recipe content
    update_progress(10)
    scores = infer_scores_via_ai(recipe)
    update_progress(80)

    # Store scores — create nutrition_data shell if needed
    nutrition = recipe.nutrition_data || recipe.build_nutrition_data(auto_calculated: true)
    nutrition.update!(diet_scores: scores)

    # Sync tags
    sync_diet_tags(recipe, scores)
    update_progress(100)

    { recipe_id: recipe.id, scores: scores, method: "ai_inference" }
  end

  def infer_scores_via_ai(recipe)
    client = Ai::Client.new
    ingredient_list = recipe.ingredients.pluck(:name).join(", ")

    messages = [ {
      role: "user",
      content: "Analyze this recipe for diet compatibility:\n\n" \
               "Title: #{recipe.title}\n" \
               "Category: #{recipe.category}\n" \
               "Description: #{recipe.description}\n" \
               "Ingredients: #{ingredient_list}\n\n" \
               "Score this recipe's compatibility with each diet on a 0.0-1.0 scale."
    } ]

    tools = [ {
      name: TOOL_NAME,
      description: "Return diet compatibility scores for a recipe",
      input_schema: {
        type: "object",
        properties: DietCategorizer::DIET_TAG_SLUGS.values.each_with_object({}) { |slug, props|
          props[slug] = { type: "number", description: "Compatibility score 0.0-1.0 for #{slug} diet" }
        },
        required: DietCategorizer::DIET_TAG_SLUGS.values
      }
    } ]

    system_prompt = "You are a nutrition expert. Score each diet 0.0-1.0 based on the recipe's " \
                    "likely macro profile and ingredient compatibility. " \
                    "1.0 = perfect fit, 0.0 = completely incompatible. " \
                    "Be conservative — only score above 0.7 if the recipe clearly fits the diet."

    result = client.chat_with_tools(messages: messages, tools: tools, system: system_prompt)
    normalize_ai_scores(result[:input])
  end

  def normalize_ai_scores(input)
    DietCategorizer::DIET_TAG_SLUGS.values.each_with_object({}) do |slug, scores|
      value = input[slug.to_s] || input[slug.to_sym] || 0.0
      scores[slug] = [ [ value.to_f, 0.0 ].max, 1.0 ].min.round(2)
    end
  end

  def sync_diet_tags(recipe, scores)
    account = recipe.account
    qualifying = scores.select { |_, s| s >= DietCategorizer::COMPATIBILITY_THRESHOLD }
    tag_names = qualifying.keys.map { |slug| "#{DietCategorizer::TAG_PREFIX}#{slug}" }

    new_tags = tag_names.map { |name| account.tags.find_or_create_by!(name: name) }
    existing_non_diet = recipe.tags.reject { |t| t.name.start_with?(DietCategorizer::TAG_PREFIX) }
    recipe.tags = existing_non_diet + new_tags
  end
end

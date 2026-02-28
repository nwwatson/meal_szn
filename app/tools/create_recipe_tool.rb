# frozen_string_literal: true

class CreateRecipeTool < ApplicationTool
  tool_name "create_recipe"
  description "Create a new recipe with title, ingredients, instructions, and optional nutrition data."

  arguments do
    required(:title).filled(:string).description("Recipe title")
    optional(:description).filled(:string).description("Brief description of the recipe")
    optional(:category).filled(:string).description("Category: breakfast, lunch, dinner, sides, snacks, or sauces")
    optional(:servings).filled(:integer).description("Number of servings")
    optional(:prep_time).filled(:integer).description("Prep time in minutes")
    optional(:cook_time).filled(:integer).description("Cook time in minutes")
    optional(:source).filled(:string).description("Recipe source URL or attribution")
    optional(:ingredients).array(:str?).description("List of ingredient strings, e.g. '2 cups almond flour'")
    optional(:instructions).array(:str?).description("List of instruction steps in order")
    optional(:calories).filled(:integer).description("Calories per serving")
    optional(:fat).filled(:float).description("Fat grams per serving")
    optional(:protein).filled(:float).description("Protein grams per serving")
    optional(:carbs).filled(:float).description("Total carbs grams per serving")
    optional(:fiber).filled(:float).description("Fiber grams per serving")
  end

  def call(title:, description: nil, category: nil, servings: nil, prep_time: nil, cook_time: nil,
           source: nil, ingredients: [], instructions: [], calories: nil, fat: nil, protein: nil,
           carbs: nil, fiber: nil)
    recipe = current_account.recipes.build(
      title: title,
      description: description,
      category: category,
      servings: servings,
      prep_time: prep_time,
      cook_time: cook_time,
      source: source
    )

    ingredients.each_with_index do |text, i|
      recipe.ingredients.build(name: text, display_order: i)
    end

    instructions.each_with_index do |text, i|
      recipe.instructions.build(step_number: i + 1, instruction: text)
    end

    if calories || fat || protein || carbs || fiber
      recipe.build_nutrition_data(
        calories: calories, fat: fat, protein: protein, carbs: carbs, fiber: fiber
      )
    end

    if recipe.save
      {
        content: [
          { type: "text", text: JSON.generate({ recipe: recipe.reload.to_api_response }) }
        ]
      }
    else
      { content: [ { type: "text", text: JSON.generate({ errors: recipe.errors.full_messages }) } ], isError: true }
    end
  end
end

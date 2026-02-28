# frozen_string_literal: true

class ListRecipesTool < ApplicationTool
  tool_name "list_recipes"
  description "Search and filter recipes in the account's catalog. Returns a list of recipes with basic info and nutrition."

  annotations(
    read_only_hint: true,
    open_world_hint: false
  )

  arguments do
    optional(:query).filled(:string).description("Search text to match against recipe titles, descriptions, and ingredients")
    optional(:category).filled(:string).description("Filter by category: breakfast, lunch, dinner, sides, snacks, or sauces")
    optional(:max_cook_time).filled(:integer).description("Maximum total cook time in minutes")
    optional(:min_calories).filled(:integer).description("Minimum calories per serving")
    optional(:max_calories).filled(:integer).description("Maximum calories per serving")
    optional(:sort).filled(:string).description("Sort order: newest, alphabetical, quickest, or most_used")
    optional(:limit).filled(:integer).description("Maximum number of recipes to return (default: 20)")
  end

  def call(query: nil, category: nil, max_cook_time: nil, min_calories: nil, max_calories: nil, sort: nil, limit: 20)
    recipes = current_account.recipes
      .includes(:nutrition_data, :tags)
      .by_category(category)
      .by_search(query)
      .by_cook_time(max_cook_time)
      .by_calorie_range(min_calories, max_calories)
      .sorted_by(sort)
      .limit(limit)

    {
      content: [
        {
          type: "text",
          text: JSON.generate({
            recipes: recipes.map(&:to_meal_planning_response),
            total: recipes.size
          })
        }
      ]
    }
  end
end

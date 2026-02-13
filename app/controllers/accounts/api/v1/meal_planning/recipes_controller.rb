class Accounts::Api::V1::MealPlanning::RecipesController < Accounts::Api::V1::ApplicationController
  # GET /api/v1/meal_planning/recipes
  # Returns recipes optimized for Claude meal planning with full nutrition info
  def index
    recipes = current_account.recipes
      .includes(:ingredients, :nutrition_data)
      .by_category(params[:category])
      .order(:title)

    render json: {
      recipes: recipes.map(&:to_meal_planning_response),
      meta: {
        total: current_account.recipes.count,
        categories: Recipe.categories.keys.index_with { |cat|
          current_account.recipes.where(category: cat).count
        },
        nutrition_summary: nutrition_summary
      }
    }
  end

  # GET /api/v1/meal_planning/recipes/:id
  # Returns single recipe with full nutrition details
  def show
    recipe = current_account.recipes
      .includes(:ingredients, :instructions, :nutrition_data, :tips)
      .find(params[:id])

    render json: {
      recipe: recipe.to_api_response.merge(
        nutrition_per_serving: recipe.nutrition_data&.to_meal_planning_response
      )
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Recipe not found" }, status: :not_found
  end

  private

  def nutrition_summary
    recipes_with_nutrition = current_account.recipes.joins(:nutrition_data)

    return {} if recipes_with_nutrition.empty?

    {
      average_calories: recipes_with_nutrition.average("recipe_nutrition_data.calories").to_i,
      calorie_range: {
        min: recipes_with_nutrition.minimum("recipe_nutrition_data.calories"),
        max: recipes_with_nutrition.maximum("recipe_nutrition_data.calories")
      },
      recipes_with_nutrition_count: recipes_with_nutrition.count,
      recipes_without_nutrition_count: current_account.recipes.left_joins(:nutrition_data)
        .where(recipe_nutrition_data: { id: nil }).count
    }
  end
end

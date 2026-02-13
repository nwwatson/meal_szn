class Accounts::Api::V1::RecipesController < Accounts::Api::V1::ApplicationController
  before_action :require_write_permission!, only: %i[create update destroy]
  before_action :set_recipe, only: %i[show update destroy]

  # GET /api/v1/recipes
  def index
    recipes = current_account.recipes
      .includes(:ingredients, :instructions, :nutrition_data, :tips, :tags)
      .by_category(params[:category])
      .by_tags(params[:tags])
      .order(created_at: :desc)

    recipes = recipes.limit(params[:limit].to_i) if params[:limit].present?

    render json: {
      recipes: recipes.map(&:to_api_response),
      meta: {
        total: current_account.recipes.count,
        categories: Recipe.categories.keys.index_with { |cat| current_account.recipes.where(category: cat).count },
        tags: current_account.tags.alphabetical.pluck(:id, :name).map { |id, name| { id: id, name: name } }
      }
    }
  end

  # GET /api/v1/recipes/:id
  def show
    render json: { recipe: @recipe.to_api_response }
  end

  # POST /api/v1/recipes
  def create
    @recipe = current_account.recipes.build(recipe_params)

    if @recipe.save
      @recipe.sync_tags_from_list(params[:recipe][:tag_list], current_account) if params.dig(:recipe, :tag_list)
      render json: { recipe: @recipe.reload.to_api_response }, status: :created
    else
      render json: { errors: @recipe.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/recipes/:id
  def update
    if @recipe.update(recipe_params)
      @recipe.sync_tags_from_list(params[:recipe][:tag_list], current_account) if params.dig(:recipe, :tag_list)
      render json: { recipe: @recipe.reload.to_api_response }
    else
      render json: { errors: @recipe.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/recipes/:id
  def destroy
    @recipe.destroy
    head :no_content
  end

  private

  def set_recipe
    @recipe = current_account.recipes.includes(:tags).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Recipe not found" }, status: :not_found
  end

  def recipe_params
    params.require(:recipe).permit(
      :title,
      :description,
      :category,
      :source,
      :servings,
      :prep_time,
      :cook_time,
      ingredients_attributes: %i[id name quantity unit display_order _destroy],
      instructions_attributes: %i[id step_number instruction _destroy],
      nutrition_data_attributes: %i[
        id calories fat protein carbs fiber
        sodium potassium magnesium _destroy
      ],
      tips_attributes: %i[id tip _destroy]
    )
  end
end

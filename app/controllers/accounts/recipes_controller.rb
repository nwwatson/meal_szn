class Accounts::RecipesController < ApplicationController
  before_action :set_recipe, only: %i[show edit update destroy resolve_ingredients apply_resolution]
  before_action :set_unit_options, only: %i[new edit create update resolve_ingredients]

  def index
    @recipes = Current.account.recipes
      .includes(:nutrition_data, :tags, image_attachment: :blob)
      .by_category(params[:category])
      .by_tags(params[:tags])
      .order(created_at: :desc)

    @categories = Recipe.categories.keys.map do |category|
      [ category.titleize, category, Current.account.recipes.where(category: category).count ]
    end

    @tags = Current.account.tags.alphabetical.with_recipe_count
  end

  def show
    @meal_plans = Current.account.meal_plans
      .where("end_date >= ?", Date.current)
      .includes(:days)
      .order(start_date: :asc)
  end

  def new
    @recipe = Current.account.recipes.build
    @recipe.ingredients.build
    @recipe.instructions.build
    @recipe.build_nutrition_data
  end

  def edit
    @recipe.ingredients.build if @recipe.ingredients.empty?
    @recipe.instructions.build if @recipe.instructions.empty?
    @recipe.build_nutrition_data unless @recipe.nutrition_data
  end

  def create
    @recipe = Current.account.recipes.build(recipe_params)

    if @recipe.save
      @recipe.sync_tags_from_list(params[:recipe][:tag_list], Current.account)
      handle_nutrition_after_save
    else
      @recipe.ingredients.build if @recipe.ingredients.empty?
      @recipe.instructions.build if @recipe.instructions.empty?
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @recipe.update(recipe_params)
      @recipe.sync_tags_from_list(params[:recipe][:tag_list], Current.account)
      handle_nutrition_after_save
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @recipe.destroy
    redirect_to recipes_path, notice: "Recipe was successfully deleted."
  end

  def resolve_ingredients
    @unresolved = @recipe.unresolved_ingredients
    redirect_to recipe_path(@recipe), notice: "All ingredients are already matched." if @unresolved.empty?
  end

  def apply_resolution
    resolutions = params[:resolutions] || {}

    resolutions.each do |ingredient_id, fdc_id|
      next if fdc_id.blank?

      ingredient = @recipe.ingredients.find_by(id: ingredient_id)
      next unless ingredient

      # Fetch full food data and import
      client = Usda::Client.new
      api_data = client.food(fdc_id.to_i)
      item = Usda::FoodImporter.new(api_data).import

      # Create alias from ingredient name
      normalized = NutritionItem.normalize_name(ingredient.name)
      item.aliases.find_or_create_by(name: normalized)

      # Link ingredient
      ingredient.update!(nutrition_item: item)
    end

    # Recalculate nutrition
    result = Nutrition::Calculator.new(@recipe.reload).calculate
    if result.success?
      apply_calculated_nutrition(result)
      redirect_to recipe_path(@recipe), notice: "Nutrition calculated from ingredients."
    else
      @unresolved = result.unresolved_ingredients
      flash.now[:alert] = "Some ingredients still need to be matched."
      render :resolve_ingredients, status: :unprocessable_entity
    end
  end

  def search_usda
    query = params[:query].to_s.strip
    if query.present?
      client = Usda::Client.new
      response = client.search(query)
      @results = response["foods"] || []
    else
      @results = []
    end

    render partial: "usda_search_results", locals: { results: @results }
  rescue Usda::Client::ApiError => e
    @results = []
    @error = e.message
    render partial: "usda_search_results", locals: { results: @results, error: @error }
  end

  private

  def set_recipe
    @recipe = Current.account.recipes
      .includes(:ingredients, :instructions, :nutrition_data, :tips, :tags)
      .find(params[:id])
  end

  def set_unit_options
    @unit_options = Ingredient.grouped_unit_options(Current.user.settings&.unit_system || "standard")
  end

  def handle_nutrition_after_save
    nutrition_mode = params[:recipe][:nutrition_mode]

    if nutrition_mode == "auto"
      result = Nutrition::Calculator.new(@recipe.reload).calculate
      if result.success?
        apply_calculated_nutrition(result)
        redirect_to recipe_path(@recipe), notice: "Recipe saved with calculated nutrition."
      else
        redirect_to resolve_ingredients_recipe_path(@recipe), notice: "Some ingredients need to be matched for nutrition calculation."
      end
    else
      redirect_to recipe_path(@recipe), notice: "Recipe was successfully saved."
    end
  end

  def apply_calculated_nutrition(result)
    nutrition = @recipe.nutrition_data || @recipe.build_nutrition_data
    nutrition.update!(result.nutrition_data)
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
      :image,
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

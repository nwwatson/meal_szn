class Accounts::Api::V1::RecipesController < Accounts::Api::V1::ApplicationController
  include AiRateLimited

  before_action :require_write_permission!, only: %i[create update destroy import_url import_photo import_confirm calculate_nutrition]
  before_action :set_recipe, only: %i[show update destroy calculate_nutrition]
  before_action :set_task, only: %i[import_status import_confirm]
  before_action -> { check_ai_rate_limit!(:recipe_import) }, only: %i[import_url import_photo]

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

  # POST /api/v1/recipes/:id/calculate_nutrition
  def calculate_nutrition
    if @recipe.ingredients.none?
      render json: { error: "Recipe has no ingredients" }, status: :unprocessable_entity
      return
    end

    result = Nutrition::Calculator.new(@recipe.reload).calculate

    if result.success?
      nutrition = @recipe.nutrition_data || @recipe.build_nutrition_data
      nutrition.update!(result.nutrition_data)
      render json: { recipe: @recipe.reload.to_api_response }
    else
      unresolved_names = result.unresolved_ingredients.map(&:name)
      render json: {
        error: "Could not resolve all ingredients",
        unresolved_ingredients: unresolved_names
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/recipes/import_url
  def import_url
    url = params[:url].to_s.strip
    if url.blank?
      render json: { error: "URL is required" }, status: :bad_request
      return
    end

    task = current_account.ai_task_statuses.create!(task_type: "recipe_import")
    RecipeImportJob.perform_later(task.id, url: url)

    render json: { task_id: task.id, status: task.status }, status: :created
  end

  # POST /api/v1/recipes/import_photo
  def import_photo
    photos = params[:photos]
    if photos.blank?
      render json: { error: "At least one photo is required" }, status: :bad_request
      return
    end

    blob_ids = photos.map do |photo|
      ActiveStorage::Blob.create_and_upload!(
        io: photo,
        filename: photo.original_filename,
        content_type: photo.content_type
      ).id
    end

    task = current_account.ai_task_statuses.create!(task_type: "recipe_photo_import")
    RecipeImportPhotoJob.perform_later(task.id, blob_ids: blob_ids)

    render json: { task_id: task.id, status: task.status }, status: :created
  end

  # GET /api/v1/recipes/import_status/:task_id
  def import_status
    response = {
      task_id: @task.id,
      status: @task.status,
      progress_percentage: @task.progress_percentage
    }

    if @task.completed?
      raw = @task.result
      response[:result] = raw.is_a?(String) ? JSON.parse(raw) : raw
    end
    response[:error_message] = @task.error_message if @task.failed?

    render json: response
  end

  # POST /api/v1/recipes/import_confirm/:task_id
  def import_confirm
    unless @task.completed?
      render json: { error: "Task is not yet completed" }, status: :unprocessable_entity
      return
    end

    raw_result = @task.result
    result = (raw_result.is_a?(String) ? JSON.parse(raw_result) : raw_result).deep_symbolize_keys
    recipe_attrs = build_recipe_from_result(result)
    recipe_attrs.merge!(confirm_overrides) if params[:recipe].present?

    @recipe = current_account.recipes.build(recipe_attrs)

    if @recipe.save
      render json: { recipe: @recipe.reload.to_api_response }, status: :created
    else
      render json: { errors: @recipe.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_recipe
    @recipe = current_account.recipes.includes(:tags).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Recipe not found" }, status: :not_found
  end

  def set_task
    @task = current_account.ai_task_statuses.find(params[:task_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Task not found" }, status: :not_found
  end

  def build_recipe_from_result(result)
    attrs = {
      title: result[:title],
      description: result[:description],
      servings: result[:servings],
      prep_time: result[:prep_time],
      cook_time: result[:cook_time],
      source: result[:source]
    }

    if result[:ingredients].present?
      attrs[:ingredients_attributes] = result[:ingredients].each_with_index.map do |text, i|
        { name: text.to_s, display_order: i }
      end
    end

    if result[:instructions].present?
      attrs[:instructions_attributes] = result[:instructions].map do |instr|
        if instr.is_a?(Hash)
          instr = instr.deep_symbolize_keys
          { step_number: instr[:step_number], instruction: instr[:instruction] }
        else
          { step_number: 1, instruction: instr.to_s }
        end
      end
    end

    if result[:nutrition].is_a?(Hash)
      nutrition = result[:nutrition].deep_symbolize_keys
      attrs[:nutrition_data_attributes] = {
        calories: nutrition[:calories],
        fat: nutrition[:fat],
        protein: nutrition[:protein],
        carbs: nutrition[:carbs],
        fiber: nutrition[:fiber],
        sodium: nutrition[:sodium]
      }
    end

    attrs
  end

  def confirm_overrides
    params.require(:recipe).permit(
      :title, :description, :category, :source, :servings, :prep_time, :cook_time
    ).to_h.symbolize_keys.compact_blank
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

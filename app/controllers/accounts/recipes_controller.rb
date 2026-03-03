class Accounts::RecipesController < ApplicationController
  include AiRateLimited
  include RecipeParamsPermittable

  before_action :set_recipe, only: %i[show edit update destroy resolve_ingredients apply_resolution rate]
  before_action :set_unit_options, only: %i[new edit create update resolve_ingredients]
  before_action -> { check_ai_rate_limit!(:recipe_import, redirect_path: import_url_recipes_path) },
                only: %i[start_import start_photo_import]
  before_action -> { check_ai_rate_limit!(:quick_entry, redirect_path: quick_entry_recipes_path) },
                only: :start_quick_entry

  def index
    recipes = Current.account.recipes
      .includes(:nutrition_data, :tags, image_attachment: :blob)
      .by_category(params[:category])
      .by_tags(params[:tags])
      .by_diet(params[:diet])
      .by_search(params[:q])
      .by_cook_time(params[:cook_time])
      .by_calorie_range(params[:min_calories], params[:max_calories])
      .by_min_rating(params[:min_rating])
      .sorted_by(params[:sort])

    @pagy, @recipes = pagy_countless(recipes)
    @recipe_count = Current.account.recipes
      .by_category(params[:category])
      .by_tags(params[:tags])
      .by_diet(params[:diet])
      .by_search(params[:q])
      .by_cook_time(params[:cook_time])
      .by_calorie_range(params[:min_calories], params[:max_calories])
      .by_min_rating(params[:min_rating])
      .unscope(:group)
      .distinct
      .count

    @categories = Recipe.categories.keys.map do |category|
      [ category.titleize, category, Current.account.recipes.where(category: category).count ]
    end

    @tags = Current.account.tags.alphabetical.with_recipe_count
    @diet_filters = DietCategorizer::DIET_TAG_SLUGS.map { |name, slug| [ NutritionHelper::DIET_BADGE_STYLES.dig(slug, :label) || name, slug ] }
    @active_filters = active_filters?

    if request.headers["Turbo-Frame"] && params[:page].to_i > 1
      render partial: "recipe_page", locals: { recipes: @recipes, pagy: @pagy }
    end
  end

  def show
    @meal_plans = Current.account.meal_plans
      .where("end_date >= ?", Date.current)
      .includes(days: { meals: :recipe })
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
    purge_image_if_requested
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

  def rate
    rating = params[:rating].to_i
    @recipe.update!(rating: rating.zero? ? nil : rating)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "recipe_rating_#{@recipe.id}",
          partial: "accounts/recipes/star_rating",
          locals: { recipe: @recipe, interactive: true, size: "w-6 h-6" }
        )
      end
      format.html { redirect_to recipe_path(@recipe) }
    end
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

  def import_url
    @url = params[:url]
  end

  def start_import
    url = params[:url].to_s.strip
    if url.blank?
      redirect_to import_url_recipes_path, alert: "Please enter a URL."
      return
    end

    task = Current.account.ai_task_statuses.create!(task_type: "recipe_import")
    RecipeImportJob.perform_later(task.id, url: url)

    redirect_to import_status_recipes_path(task_id: task.id)
  end

  def import_photo
  end

  def start_photo_import
    photos = params[:photos]
    if photos.blank?
      redirect_to import_photo_recipes_path, alert: "Please select at least one photo."
      return
    end

    blob_ids = photos.map do |photo|
      ActiveStorage::Blob.create_and_upload!(
        io: photo,
        filename: photo.original_filename,
        content_type: photo.content_type
      ).id
    end

    task = Current.account.ai_task_statuses.create!(task_type: "recipe_photo_import")
    RecipeImportPhotoJob.perform_later(task.id, blob_ids: blob_ids)

    redirect_to import_status_recipes_path(task_id: task.id)
  end

  def quick_entry
    @description = params[:description]
  end

  def start_quick_entry
    description = params[:description].to_s.strip
    if description.blank?
      redirect_to quick_entry_recipes_path, alert: "Please describe the recipe you want to create."
      return
    end

    task = Current.account.ai_task_statuses.create!(task_type: "recipe_generate")
    RecipeGenerateJob.perform_later(task.id, description: description, diet_name: Current.account.default_diet_name)

    redirect_to import_status_recipes_path(task_id: task.id)
  end

  def import_status
    @task = Current.account.ai_task_statuses.find(params[:task_id])
    @failed_url = failure_path_for(@task)

    if @task.completed?
      redirect_to import_review_recipes_path(task_id: @task.id)
    elsif @task.failed?
      redirect_to @failed_url, alert: "Import failed: #{@task.error_message}"
    end
  end

  def import_review
    @task = Current.account.ai_task_statuses.find(params[:task_id])
    redirect_to import_url_recipes_path, alert: "Import is not yet complete." unless @task.completed?

    result = @task.result.deep_symbolize_keys
    @recipe = Current.account.recipes.build(
      title: result[:title],
      description: result[:description],
      servings: result[:servings],
      prep_time: result[:prep_time],
      cook_time: result[:cook_time],
      source: result[:source]
    )

    build_ingredients_from_import(result[:ingredients] || [])
    build_instructions_from_import(result[:instructions] || [])
    build_nutrition_from_import(result[:nutrition])
    attach_imported_image(result[:image_url])

    @recipe.ingredients.build if @recipe.ingredients.empty?
    @recipe.instructions.build if @recipe.instructions.empty?
    @recipe.build_nutrition_data unless @recipe.nutrition_data

    set_unit_options
    render :new
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

  def active_filters?
    params[:q].present? || params[:category].present? || params[:tags].present? ||
      params[:diet].present? || params[:cook_time].present? ||
      params[:min_calories].present? || params[:max_calories].present? ||
      params[:min_rating].present? ||
      (params[:sort].present? && params[:sort] != "newest")
  end

  FAILURE_PATHS = {
    "recipe_photo_import" => :import_photo_recipes_path,
    "recipe_generate" => :quick_entry_recipes_path
  }.freeze

  def failure_path_for(task)
    method_name = FAILURE_PATHS[task.task_type] || :import_url_recipes_path
    send(method_name)
  end

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

  def build_ingredients_from_import(ingredients)
    ingredients.each_with_index do |text, index|
      parsed = parse_ingredient_text(text.to_s)
      @recipe.ingredients.build(
        name: parsed[:name],
        quantity: parsed[:quantity],
        unit: parsed[:unit],
        display_order: index
      )
    end
  end

  def build_instructions_from_import(instructions)
    instructions.each do |instr|
      instr = instr.is_a?(Hash) ? instr.deep_symbolize_keys : { step_number: 1, instruction: instr.to_s }
      @recipe.instructions.build(
        step_number: instr[:step_number],
        instruction: instr[:instruction]
      )
    end
  end

  def build_nutrition_from_import(nutrition)
    return unless nutrition.is_a?(Hash)
    nutrition = nutrition.deep_symbolize_keys
    @recipe.build_nutrition_data(
      calories: nutrition[:calories],
      fat: nutrition[:fat],
      protein: nutrition[:protein],
      carbs: nutrition[:carbs],
      fiber: nutrition[:fiber],
      sodium: nutrition[:sodium]
    )
  end

  def attach_imported_image(image_url)
    return if image_url.blank?

    uri = URI.parse(image_url)
    return unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    response = Net::HTTP.get_response(uri)
    return unless response.is_a?(Net::HTTPSuccess)

    content_type = response["content-type"]&.split(";")&.first
    return unless content_type&.in?(Recipe::ALLOWED_IMAGE_TYPES)

    extension = content_type.split("/").last
    @recipe.image.attach(
      io: StringIO.new(response.body),
      filename: "imported-cover.#{extension}",
      content_type: content_type
    )
  rescue URI::InvalidURIError, SocketError, Timeout::Error, Errno::ECONNREFUSED
    # Silently skip — image is optional
    nil
  end

  def parse_ingredient_text(text)
    # Match patterns like "2 cups almond flour" or "1/2 tsp salt"
    match = text.match(/\A([\d\s\/½¼¾⅓⅔⅛.]+)?\s*(#{Ingredient::UNITS_PATTERN})?\s*(.+)\z/i)
    if match
      { quantity: match[1]&.strip, unit: match[2]&.strip&.downcase, name: match[3]&.strip }
    else
      { quantity: nil, unit: nil, name: text.strip }
    end
  end

  def purge_image_if_requested
    if params[:purge_image_id].present?
      attachment = @recipe.images.find { |img| img.id.to_s == params[:purge_image_id].to_s }
      attachment&.purge_later
    end
  end

  def recipe_params
    permitted_recipe_params(:image, images: [])
  end
end

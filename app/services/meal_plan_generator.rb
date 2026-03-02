# frozen_string_literal: true

class MealPlanGenerator
  class GenerationError < StandardError; end

  PREFERENCE_OPTIONS = {
    "no_repeats" => "Never repeat the same recipe in the same week",
    "quick_weekday" => "Prefer quick meals (under 30 min total time) on weekdays (Monday-Friday)",
    "skip_breakfast" => "Do not assign any breakfast meals",
    "skip_lunch" => "Do not assign any lunch meals",
    "batch_cook_sunday" => "On Sunday, plan recipes that make good leftovers for the week",
    "high_variety" => "Maximize variety — use as many different recipes as possible"
  }.freeze

  MIN_RECIPES_REQUIRED = 3

  SYSTEM_RULES = <<~RULES.freeze
    You are a meal planning assistant for a family-oriented meal planning app.
    Your job is to create an optimized weekly meal plan that respects dietary requirements,
    macro targets, and user preferences.

    RULES:
    - Only use recipe IDs from the provided catalog
    - Each meal assignment should have exactly one recipe
    - Aim for variety: minimize recipe repetition across the week
    - Match recipes to appropriate meal types (breakfast recipes for breakfast, etc.)
    - Consider prep/cook time when assigning meals
    - Target each participant's daily calorie goals by choosing appropriate recipes
    - These recipes have been pre-selected for variety and dietary fit. Use them all if possible to maximize rotation.
  RULES

  def initialize(meal_plan, preferences: [], special_requests: nil, ai_client: nil)
    @meal_plan = meal_plan
    @account = meal_plan.account
    @preferences = Array(preferences)
    @special_requests = special_requests.presence
    @ai_client = ai_client || Ai::Client.new(model: Ai.meal_planning_model)
  end

  def generate(&progress_callback)
    recipes = select_recipes
    validate_recipe_catalog!(recipes)

    report_progress(progress_callback, 10)

    participants = @meal_plan.participants.includes(:dietary_profile)
    constraints = build_constraints(participants)

    report_progress(progress_callback, 20)

    ai_response = call_ai(recipes, constraints)

    report_progress(progress_callback, 70)

    populate_meal_plan(ai_response, recipes)

    report_progress(progress_callback, 85)

    calculate_portions(participants) if participants.any?

    report_progress(progress_callback, 95)

    build_result_summary
  end

  private

  def select_recipes
    meal_types = active_meal_types
    participant_diets = @meal_plan.dietary_profiles.pluck(:diet_name)

    selector = RecipeSelector.new(
      @account, @meal_plan,
      meal_types: meal_types,
      participant_diets: participant_diets
    )
    selector.select
  end

  def validate_recipe_catalog!(recipes)
    if recipes.size < MIN_RECIPES_REQUIRED
      raise GenerationError,
        "Not enough recipes with nutrition data (found #{recipes.size}, need at least #{MIN_RECIPES_REQUIRED}). " \
        "Add more recipes with nutrition information to generate a meal plan."
    end
  end

  def build_constraints(participants)
    constraints = {
      days: build_day_info,
      meal_types: active_meal_types,
      preferences: @preferences.filter_map { |key| PREFERENCE_OPTIONS[key] },
      special_requests: @special_requests
    }

    if participants.any?
      constraints[:dietary_profiles] = participants.map do |p|
        profile = p.dietary_profile
        {
          name: profile.name,
          diet: profile.diet_name,
          daily_calories: profile.daily_calories_target,
          macro_targets: profile.macro_targets
        }
      end
    elsif @meal_plan.daily_calories_target
      constraints[:daily_calories_target] = @meal_plan.daily_calories_target
    end

    constraints
  end

  def build_day_info
    @meal_plan.days.order(:day_number).map do |day|
      { day_number: day.day_number, date: day.date.to_s, weekday: day.date.strftime("%A") }
    end
  end

  def active_meal_types
    types = %w[breakfast lunch dinner snack]
    types -= %w[breakfast] if @preferences.include?("skip_breakfast")
    types -= %w[lunch] if @preferences.include?("skip_lunch")
    types
  end

  def call_ai(recipes, constraints)
    @index_to_id = {}
    recipe_catalog = recipes.each_with_index.map do |recipe, idx|
      index = idx + 1
      @index_to_id[index] = recipe.id
      recipe_to_indexed_hash(recipe, index)
    end

    system_prompt = build_system_prompt(constraints)
    user_message = build_user_message(recipe_catalog, constraints)

    result = @ai_client.chat_with_tools(
      messages: [ { role: "user", content: user_message } ],
      tools: [ meal_plan_tool_definition ],
      system: system_prompt,
      max_tokens: 4096,
      feature: "meal_plan_generation"
    )

    unless result[:name] == "assign_meals"
      raise GenerationError, "AI returned unexpected tool: #{result[:name]}"
    end

    result[:input]
  end

  def recipe_to_indexed_hash(recipe, index)
    data = recipe.to_meal_planning_response
    data[:index] = index
    data
  end

  def build_system_prompt(constraints)
    # Static rules get cache_control for prompt caching; dynamic context is appended as a separate block
    blocks = [
      { type: "text", text: SYSTEM_RULES, cache_control: { type: "ephemeral" } }
    ]

    dynamic = build_dynamic_context(constraints)
    blocks << { type: "text", text: dynamic } if dynamic.present?

    blocks
  end

  def build_dynamic_context(constraints)
    parts = []

    if constraints[:dietary_profiles]&.any?
      parts << "PARTICIPANT DIETARY PROFILES:"
      constraints[:dietary_profiles].each do |profile|
        line = "- #{profile[:name]}: #{profile[:diet] || 'No specific diet'}, "
        line += "#{profile[:daily_calories] || 'no'} daily calorie target"
        if profile[:macro_targets]
          mt = profile[:macro_targets]
          line += ", macros: #{mt[:fat_g]}g fat, #{mt[:protein_g]}g protein, #{mt[:carbs_g]}g carbs" if mt[:fat_g]
        end
        parts << line
      end
    end

    if constraints[:preferences].any?
      parts << "\nUSER PREFERENCES:"
      constraints[:preferences].each { |p| parts << "- #{p}" }
    end

    if constraints[:special_requests]
      parts << "\nSPECIAL REQUESTS:\n#{constraints[:special_requests]}"
    end

    parts.join("\n")
  end

  def build_user_message(recipe_catalog, constraints)
    days_info = constraints[:days].map { |d| "Day #{d[:day_number]} (#{d[:weekday]}, #{d[:date]})" }.join(", ")
    meal_types = constraints[:meal_types].join(", ")

    <<~USER
      Create a meal plan for the following days: #{days_info}
      Meal types to plan: #{meal_types}

      Available recipes (#{recipe_catalog.size} total):

      #{recipe_catalog.map { |r| format_recipe_for_prompt(r) }.join("\n\n")}

      Assign one recipe to each meal slot for each day using the assign_meals tool.
      Choose recipes that best fit the dietary requirements and optimize for variety and nutrition balance.
    USER
  end

  def format_recipe_for_prompt(recipe)
    nutrition = recipe[:nutrition_per_serving]
    parts = [ "##{recipe[:index]} #{recipe[:title]} (#{recipe[:category]})" ]
    parts << "  Servings: #{recipe[:servings]}, Prep: #{recipe[:prep_time] || '?'}min, Cook: #{recipe[:cook_time] || '?'}min"
    if nutrition
      parts << "  #{nutrition[:calories]} cal, #{nutrition[:fat_g]}g fat, #{nutrition[:protein_g]}g protein, #{nutrition[:net_carbs_g]}g net carbs"
    end
    parts << "  Tags: #{recipe[:tags].join(', ')}" if recipe[:tags].any?
    parts.join("\n")
  end

  def meal_plan_tool_definition
    {
      name: "assign_meals",
      description: "Assign recipes to each meal slot in the meal plan.",
      input_schema: {
        type: "object",
        required: [ "days" ],
        properties: {
          days: {
            type: "array",
            items: {
              type: "object",
              required: [ "day_number", "meals" ],
              properties: {
                day_number: {
                  type: "integer",
                  description: "The day number (1-based)"
                },
                meals: {
                  type: "array",
                  items: {
                    type: "object",
                    required: [ "meal_type", "recipe_id" ],
                    properties: {
                      meal_type: {
                        type: "string",
                        enum: %w[breakfast lunch dinner snack]
                      },
                      recipe_id: {
                        type: "integer",
                        description: "The recipe index number from the catalog"
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  end

  def populate_meal_plan(ai_response, recipes)
    ai_response = ai_response.deep_stringify_keys
    recipe_lookup = recipes.index_by(&:id)
    days_lookup = @meal_plan.days.index_by(&:day_number)

    Array(ai_response["days"]).each do |day_data|
      day = days_lookup[day_data["day_number"]]
      next unless day

      Array(day_data["meals"]).each do |meal_data|
        recipe_id = resolve_recipe_id(meal_data["recipe_id"])
        recipe = recipe_lookup[recipe_id]
        next unless recipe

        meal_type = meal_data["meal_type"]
        next unless MealPlanMeal.meal_types.key?(meal_type)

        day.meals.create!(
          recipe: recipe,
          meal_type: meal_type,
          servings: 1.0
        )
      end
    end
  end

  def resolve_recipe_id(raw_id)
    # AI returns integer indices; map back to UUIDs
    if raw_id.is_a?(Integer) || (raw_id.is_a?(String) && raw_id.match?(/\A\d+\z/))
      @index_to_id[raw_id.to_i]
    else
      raw_id.to_s
    end
  end

  def calculate_portions(participants)
    participants.each do |participant|
      calculator = PortionCalculator.new(participant)
      calculator.suggest_all.each_value do |day_portions|
        day_portions.each do |meal_id, servings|
          participant.portions.create!(meal_plan_meal_id: meal_id, servings: servings)
        end
      end
    end
  end

  def report_progress(callback, percentage)
    callback&.call(percentage)
  end

  def build_result_summary
    days = @meal_plan.days.includes(meals: { recipe: :nutrition_data })
    total_meals = days.sum { |d| d.meals.size }

    {
      meals_assigned: total_meals,
      days_planned: days.size,
      preferences_applied: @preferences,
      special_requests: @special_requests
    }
  end
end

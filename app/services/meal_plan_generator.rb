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

  def initialize(meal_plan, preferences: [], special_requests: nil, ai_client: nil)
    @meal_plan = meal_plan
    @account = meal_plan.account
    @preferences = Array(preferences)
    @special_requests = special_requests.presence
    @ai_client = ai_client || Ai::Client.new
  end

  def generate(&progress_callback)
    recipes = fetch_eligible_recipes
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

  def fetch_eligible_recipes
    @account.recipes
      .joins(:nutrition_data)
      .includes(:nutrition_data, :tags)
      .where.not(recipe_nutrition_data: { calories: nil })
      .to_a
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
    recipe_catalog = recipes.map(&:to_meal_planning_response)

    system_prompt = build_system_prompt(constraints)
    user_message = build_user_message(recipe_catalog, constraints)

    result = @ai_client.chat_with_tools(
      messages: [ { role: "user", content: user_message } ],
      tools: [ meal_plan_tool_definition ],
      system: system_prompt,
      max_tokens: 8192
    )

    unless result[:name] == "assign_meals"
      raise GenerationError, "AI returned unexpected tool: #{result[:name]}"
    end

    result[:input]
  end

  def build_system_prompt(constraints)
    prompt = <<~SYSTEM
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
    SYSTEM

    if constraints[:dietary_profiles]&.any?
      prompt += "\nPARTICIPANT DIETARY PROFILES:\n"
      constraints[:dietary_profiles].each do |profile|
        prompt += "- #{profile[:name]}: #{profile[:diet] || 'No specific diet'}, "
        prompt += "#{profile[:daily_calories] || 'no'} daily calorie target"
        if profile[:macro_targets]
          mt = profile[:macro_targets]
          prompt += ", macros: #{mt[:fat_g]}g fat, #{mt[:protein_g]}g protein, #{mt[:carbs_g]}g carbs" if mt[:fat_g]
        end
        prompt += "\n"
      end
    end

    if constraints[:preferences].any?
      prompt += "\nUSER PREFERENCES:\n"
      constraints[:preferences].each { |p| prompt += "- #{p}\n" }
    end

    if constraints[:special_requests]
      prompt += "\nSPECIAL REQUESTS:\n#{constraints[:special_requests]}\n"
    end

    prompt
  end

  def build_user_message(recipe_catalog, constraints)
    days_info = constraints[:days].map { |d| "Day #{d[:day_number]} (#{d[:weekday]}, #{d[:date]})" }.join(", ")
    meal_types = constraints[:meal_types].join(", ")

    <<~USER
      Create a meal plan for the following days: #{days_info}
      Meal types to plan: #{meal_types}

      Available recipes (#{recipe_catalog.size} total):

      #{recipe_catalog.map { |r| format_recipe_for_prompt(r) }.join("\n\n")}

      Please assign one recipe to each meal slot for each day using the assign_meals tool.
      Choose recipes that best fit the dietary requirements and optimize for variety and nutrition balance.
    USER
  end

  def format_recipe_for_prompt(recipe)
    nutrition = recipe[:nutrition_per_serving]
    parts = [ "ID: #{recipe[:id]} | #{recipe[:title]} (#{recipe[:category]})" ]
    parts << "  Servings: #{recipe[:servings]}, Prep: #{recipe[:prep_time] || '?'}min, Cook: #{recipe[:cook_time] || '?'}min"
    if nutrition
      parts << "  Per serving: #{nutrition[:calories]} cal, #{nutrition[:fat_g]}g fat, #{nutrition[:protein_g]}g protein, #{nutrition[:net_carbs_g]}g net carbs"
    end
    parts << "  Tags: #{recipe[:tags].join(', ')}" if recipe[:tags].any?
    parts.join("\n")
  end

  def meal_plan_tool_definition
    {
      name: "assign_meals",
      description: "Assign recipes to each meal slot in the meal plan. Each day should have meals assigned based on the requested meal types.",
      input_schema: {
        type: "object",
        required: [ "days" ],
        properties: {
          days: {
            type: "array",
            description: "Array of day assignments",
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
                  description: "Meals assigned to this day",
                  items: {
                    type: "object",
                    required: [ "meal_type", "recipe_id" ],
                    properties: {
                      meal_type: {
                        type: "string",
                        enum: %w[breakfast lunch dinner snack],
                        description: "The type of meal"
                      },
                      recipe_id: {
                        type: "string",
                        description: "The ID of the recipe to assign"
                      },
                      servings: {
                        type: "number",
                        description: "Number of base recipe servings (default 1.0)"
                      }
                    }
                  }
                }
              }
            }
          },
          reasoning: {
            type: "string",
            description: "Brief explanation of the meal plan choices and optimization strategy"
          }
        }
      }
    }
  end

  def populate_meal_plan(ai_response, recipes)
    recipe_lookup = recipes.index_by(&:id)
    days_lookup = @meal_plan.days.index_by(&:day_number)

    Array(ai_response["days"]).each do |day_data|
      day = days_lookup[day_data["day_number"]]
      next unless day

      Array(day_data["meals"]).each do |meal_data|
        recipe = recipe_lookup[meal_data["recipe_id"]]
        next unless recipe

        meal_type = meal_data["meal_type"]
        next unless MealPlanMeal.meal_types.key?(meal_type)

        servings = (meal_data["servings"] || 1.0).to_f.clamp(0.25, 10.0)

        day.meals.create!(
          recipe: recipe,
          meal_type: meal_type,
          servings: servings
        )
      end
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

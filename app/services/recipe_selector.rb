# frozen_string_literal: true

class RecipeSelector
  SCORE_WEIGHTS = {
    usage_frequency: 0.30,
    recency_decay: 0.25,
    diet_compatibility: 0.20,
    category_fit: 0.15,
    newness_bonus: 0.10
  }.freeze

  DEFAULT_LIMIT = 50
  MIN_PER_CATEGORY = 3
  SMALL_CATALOG_THRESHOLD = 20
  NEWNESS_WINDOW = 14.days
  RECENCY_DECAY_WEEKS = 4

  def initialize(account, meal_plan, meal_types:, participant_diets: [], current_date: Date.current)
    @account = account
    @meal_plan = meal_plan
    @meal_types = meal_types
    @participant_diets = participant_diets
    @current_date = current_date
  end

  def select(limit: DEFAULT_LIMIT)
    candidates = fetch_eligible_recipes
    candidates = hard_exclude_recent(candidates)

    return candidates if candidates.size <= limit

    scored = score_recipes(candidates)
    pick_by_category(scored, limit: limit)
  end

  private

  def fetch_eligible_recipes
    @account.recipes
      .joins(:nutrition_data)
      .includes(:nutrition_data, :tags)
      .where.not(recipe_nutrition_data: { calories: nil })
      .to_a
  end

  def hard_exclude_recent(candidates)
    recent_recipe_ids = recently_used_recipe_ids(candidates.size)
    return candidates if recent_recipe_ids.empty?

    filtered = candidates.reject { |r| recent_recipe_ids.include?(r.id) }

    # If exclusion would drop below minimum viable, return all candidates
    filtered.size >= MealPlanGenerator::MIN_RECIPES_REQUIRED ? filtered : candidates
  end

  def recently_used_recipe_ids(catalog_size)
    return [] if catalog_size < SMALL_CATALOG_THRESHOLD

    meals_per_plan = @meal_types.size * (@meal_plan.duration_days || 7)
    plans_to_exclude = [ 3, catalog_size / [ meals_per_plan, 1 ].max ].min
    plans_to_exclude = [ plans_to_exclude, 1 ].max

    recent_plans = @account.meal_plans
      .where.not(id: @meal_plan.id)
      .where("end_date < ?", @current_date)
      .order(start_date: :desc)
      .limit(plans_to_exclude)

    MealPlanMeal
      .joins(meal_plan_day: :meal_plan)
      .where(meal_plan_days: { meal_plan_id: recent_plans.select(:id) })
      .distinct
      .pluck(:recipe_id)
  end

  def score_recipes(candidates)
    usage_counts = recipe_usage_counts
    last_used_dates = recipe_last_used_dates
    diet_slugs = participant_diet_slugs

    candidates.map do |recipe|
      score = 0.0
      score += SCORE_WEIGHTS[:usage_frequency] * usage_frequency_score(recipe, usage_counts)
      score += SCORE_WEIGHTS[:recency_decay] * recency_decay_score(recipe, last_used_dates)
      score += SCORE_WEIGHTS[:diet_compatibility] * diet_compatibility_score(recipe, diet_slugs)
      score += SCORE_WEIGHTS[:category_fit] * category_fit_score(recipe)
      score += SCORE_WEIGHTS[:newness_bonus] * newness_score(recipe)

      { recipe: recipe, score: score }
    end
  end

  def pick_by_category(scored, limit:)
    # Allocate slots proportionally across active meal-type categories
    category_map = map_meal_types_to_categories
    per_category = [ limit / [ category_map.size, 1 ].max, MIN_PER_CATEGORY ].max

    selected = Set.new
    remaining = scored.sort_by { |s| -s[:score] }

    # First pass: fill each category up to its allocation
    category_map.each do |category|
      category_recipes = remaining.select { |s| s[:recipe].category == category }
      picks = category_recipes.first(per_category)
      picks.each { |s| selected.add(s[:recipe].id) }
    end

    # Second pass: fill remaining slots with highest-scoring uncategorized recipes
    if selected.size < limit
      remaining.each do |s|
        break if selected.size >= limit
        selected.add(s[:recipe].id)
      end
    end

    scored.select { |s| selected.include?(s[:recipe].id) }
      .sort_by { |s| -s[:score] }
      .map { |s| s[:recipe] }
  end

  # --- Scoring functions (each returns 0.0–100.0) ---

  def usage_frequency_score(recipe, usage_counts)
    count = usage_counts[recipe.id] || 0
    return 0.0 if count.zero?

    max_count = usage_counts.values.max || 1
    (count.to_f / max_count * 100.0)
  end

  def recency_decay_score(recipe, last_used_dates)
    last_used = last_used_dates[recipe.id]
    return 80.0 unless last_used # Never used — good candidate

    weeks_ago = ((@current_date - last_used).to_f / 7).ceil
    if weeks_ago <= RECENCY_DECAY_WEEKS
      # Recently used — penalize with exponential decay
      (weeks_ago.to_f / RECENCY_DECAY_WEEKS * 60.0)
    else
      # Not used recently — full score
      100.0
    end
  end

  def diet_compatibility_score(recipe, diet_slugs)
    return 50.0 if diet_slugs.empty? # No dietary context — neutral score

    scores = recipe.nutrition_data&.diet_scores
    return 50.0 unless scores.present?

    avg = diet_slugs.sum { |slug| (scores[slug] || 0.0).to_f } / diet_slugs.size
    (avg * 100.0)
  end

  def category_fit_score(recipe)
    matching_categories = map_meal_types_to_categories
    matching_categories.include?(recipe.category) ? 100.0 : 20.0
  end

  def newness_score(recipe)
    days_old = (@current_date - recipe.created_at.to_date).to_i
    days_old <= NEWNESS_WINDOW.in_days.to_i ? 100.0 : 0.0
  end

  # --- Data lookups (memoized) ---

  def recipe_usage_counts
    @recipe_usage_counts ||= MealPlanMeal
      .joins(meal_plan_day: :meal_plan)
      .where(meal_plan_days: { meal_plans: { account_id: @account.id } })
      .where.not(meal_plan_days: { meal_plan_id: @meal_plan.id })
      .group(:recipe_id)
      .count
  end

  def recipe_last_used_dates
    @recipe_last_used_dates ||= MealPlanMeal
      .joins(meal_plan_day: :meal_plan)
      .where(meal_plan_days: { meal_plans: { account_id: @account.id } })
      .where.not(meal_plan_days: { meal_plan_id: @meal_plan.id })
      .group(:recipe_id)
      .maximum("meal_plan_days.date")
  end

  def participant_diet_slugs
    @participant_diet_slugs ||= @participant_diets.filter_map do |diet_name|
      DietCategorizer::DIET_TAG_SLUGS[diet_name]
    end.uniq
  end

  def map_meal_types_to_categories
    @map_meal_types_to_categories ||= @meal_types.map do |mt|
      case mt
      when "breakfast" then "breakfast"
      when "lunch" then "lunch"
      when "dinner" then "dinner"
      when "snack" then "snacks"
      end
    end.compact.uniq
  end
end

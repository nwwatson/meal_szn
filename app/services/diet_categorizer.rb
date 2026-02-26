# frozen_string_literal: true

class DietCategorizer
  COMPATIBILITY_THRESHOLD = 0.7
  TAG_PREFIX = "diet:"
  EXCLUDED_DIETS = [ "If It Fits Your Macros (IIFYM)" ].freeze

  DIET_TAG_SLUGS = {
    "Ketogenic (Keto)" => "keto",
    "Low-Carb (non-keto)" => "low-carb",
    "Paleo" => "paleo",
    "Zone Diet" => "zone",
    "Mediterranean" => "mediterranean",
    "High-Protein / Bodybuilding" => "high-protein",
    "Carnivore" => "carnivore",
    "Vegan (whole-food)" => "vegan",
    "Standard / USDA Guidelines" => "standard"
  }.freeze

  def initialize(recipe)
    @recipe = recipe
    @nutrition = recipe.nutrition_data
  end

  def categorize!
    return {} unless @nutrition&.calories&.positive?

    scores = calculate_scores
    @nutrition.update_column(:diet_scores, scores)
    sync_diet_tags(scores)
    scores
  end

  def calculate_scores
    return {} unless @nutrition&.calories&.positive?

    scorable_diets.each_with_object({}) do |diet, scores|
      slug = DIET_TAG_SLUGS[diet["name"]]
      next unless slug

      scores[slug] = score_for_diet(diet).round(2)
    end
  end

  private

  def scorable_diets
    DietRegistry.all_diets.reject { |d| EXCLUDED_DIETS.include?(d["name"]) }
  end

  def score_for_diet(diet)
    fat_cal = @nutrition.fat.to_f * 9
    protein_cal = @nutrition.protein.to_f * 4
    carbs_cal = @nutrition.net_carbs.to_f * 4
    total_cal = @nutrition.calories.to_f

    return 0.0 if total_cal.zero?

    actual_fat_pct = fat_cal / total_cal * 100
    actual_protein_pct = protein_cal / total_cal * 100
    actual_carbs_pct = carbs_cal / total_cal * 100

    fat_score = range_score(actual_fat_pct, diet["fat_pct"])
    protein_score = range_score(actual_protein_pct, diet["protein_pct"])
    carbs_score = range_score(actual_carbs_pct, diet["carbs_pct"])

    (fat_score + protein_score + carbs_score) / 3.0
  end

  def range_score(actual, range)
    return 0.0 if range.nil?

    min = range["min"].to_f
    max = range["max"].to_f
    grace = 15.0

    if actual >= min && actual <= max
      1.0
    elsif actual < min
      distance = min - actual
      [ 1.0 - (distance / grace), 0.0 ].max
    else
      distance = actual - max
      [ 1.0 - (distance / grace), 0.0 ].max
    end
  end

  def sync_diet_tags(scores)
    account = @recipe.account
    qualifying_slugs = scores.select { |_, score| score >= COMPATIBILITY_THRESHOLD }.keys
    qualifying_tag_names = qualifying_slugs.map { |slug| "#{TAG_PREFIX}#{slug}" }

    new_diet_tags = qualifying_tag_names.map do |name|
      account.tags.find_or_create_by!(name: name)
    end

    existing_non_diet_tags = @recipe.tags.reject { |t| t.name.start_with?(TAG_PREFIX) }
    @recipe.tags = existing_non_diet_tags + new_diet_tags
  end
end

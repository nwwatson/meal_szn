class PortionCalculator
  MEAL_TYPE_WEIGHTS = {
    "breakfast" => 0.25,
    "lunch" => 0.30,
    "dinner" => 0.35,
    "snack" => 0.10
  }.freeze

  MIN_SERVINGS = 0.25
  MAX_SERVINGS = 10.0

  def initialize(participant)
    @participant = participant
    @daily_calories = participant.daily_calories_target
  end

  def suggest_portions_for_day(day)
    return {} unless @daily_calories && @daily_calories > 0

    meals = day.meals.includes(recipe: :nutrition_data)
    return {} if meals.empty?

    # Group meals by type and count
    meals_by_type = meals.group_by(&:meal_type)

    portions = {}
    meals.each do |meal|
      type_weight = MEAL_TYPE_WEIGHTS[meal.meal_type] || 0.10
      type_count = meals_by_type[meal.meal_type]&.size || 1

      allocated_calories = @daily_calories * type_weight / type_count
      recipe_cal = meal.recipe.nutrition_data&.calories.to_f

      if recipe_cal > 0
        servings = (allocated_calories / recipe_cal).round(2)
        servings = servings.clamp(MIN_SERVINGS, MAX_SERVINGS)
      else
        servings = 1.0
      end

      portions[meal.id] = servings
    end

    portions
  end

  def suggest_all
    meal_plan = @participant.meal_plan
    days = meal_plan.days.includes(meals: { recipe: :nutrition_data })

    result = {}
    days.each do |day|
      day_portions = suggest_portions_for_day(day)
      result[day.id] = day_portions if day_portions.any?
    end
    result
  end
end

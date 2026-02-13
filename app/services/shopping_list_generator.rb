class ShoppingListGenerator
  def initialize(meal_plan, user:)
    @meal_plan = meal_plan
    @user = user
  end

  def generate
    items_data = aggregate_ingredients

    shopping_list = @meal_plan.shopping_lists.create!(
      account: @meal_plan.account,
      user: @user,
      name: "#{@meal_plan.name} Shopping List"
    )

    items_data.each do |_key, item|
      shopping_list.items.create!(
        name: item[:name],
        quantity: format_quantity(item[:quantity]),
        unit: item[:unit]
      )
    end

    shopping_list
  end

  private

  def aggregate_ingredients
    items = {}

    has_participants = @meal_plan.participants.any?

    @meal_plan.days.includes(meals: { recipe: :ingredients, portions: [] }).each do |day|
      day.meals.each do |meal|
        total_servings = if has_participants
          meal.portions.sum(:servings)
        else
          meal.servings.to_f
        end
        total_servings = meal.servings.to_f if total_servings.zero?
        scale = meal.recipe.servings.to_f > 0 ? total_servings / meal.recipe.servings.to_f : 1.0

        meal.recipe.ingredients.each do |ingredient|
          key = "#{ingredient.name.downcase.strip}||#{ingredient.unit.to_s.downcase.strip}"
          parsed_qty = Nutrition::QuantityParser.parse(ingredient.quantity)

          if items[key]
            if parsed_qty && items[key][:quantity].is_a?(Numeric)
              items[key][:quantity] += parsed_qty * scale
            end
          else
            items[key] = {
              name: ingredient.name.strip,
              unit: ingredient.unit.to_s.strip,
              quantity: parsed_qty ? parsed_qty * scale : ingredient.quantity
            }
          end
        end
      end
    end

    items
  end

  def format_quantity(qty)
    return qty.to_s if qty.is_a?(String) || qty.nil?

    # Format nicely: remove trailing zeros
    if qty == qty.to_i.to_f
      qty.to_i.to_s
    else
      format("%.2f", qty).sub(/0+\z/, "").sub(/\.\z/, "")
    end
  end
end

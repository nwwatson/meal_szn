class RecipeFork
  def self.call(source_recipe, target_account, shared_by: nil)
    new(source_recipe, target_account, shared_by: shared_by).call
  end

  def initialize(source_recipe, target_account, shared_by: nil)
    @source = source_recipe
    @target_account = target_account
    @shared_by = shared_by
  end

  def call
    ActiveRecord::Base.transaction do
      fork_recipe
      fork_ingredients
      fork_instructions
      fork_nutrition_data
      fork_tips
      fork_tags
      fork_attachments
      @forked
    end
  end

  private

  def fork_recipe
    @forked = @target_account.recipes.create!(
      title: @source.title,
      description: @source.description,
      category: @source.category,
      source: @source.source,
      servings: @source.servings,
      prep_time: @source.prep_time,
      cook_time: @source.cook_time,
      forked_from: @source,
      shared_by: @shared_by
    )
  end

  def fork_ingredients
    @source.ingredients.each do |ingredient|
      @forked.ingredients.create!(
        name: ingredient.name,
        quantity: ingredient.quantity,
        unit: ingredient.unit,
        display_order: ingredient.display_order,
        nutrition_item_id: ingredient.nutrition_item_id
      )
    end
  end

  def fork_instructions
    @source.instructions.each do |instruction|
      @forked.instructions.create!(
        step_number: instruction.step_number,
        instruction: instruction.instruction
      )
    end
  end

  def fork_nutrition_data
    return unless @source.nutrition_data

    nd = @source.nutrition_data
    @forked.create_nutrition_data!(
      calories: nd.calories,
      fat: nd.fat,
      protein: nd.protein,
      carbs: nd.carbs,
      fiber: nd.fiber,
      net_carbs: nd.net_carbs,
      sodium: nd.sodium,
      potassium: nd.potassium,
      magnesium: nd.magnesium,
      auto_calculated: nd.auto_calculated,
      diet_scores: nd.diet_scores
    )
  end

  def fork_tips
    @source.tips.each do |tip|
      @forked.tips.create!(tip: tip.tip)
    end
  end

  def fork_tags
    @source.tags.each do |tag|
      target_tag = @target_account.tags.find_or_create_by!(name: tag.name)
      @forked.tags << target_tag unless @forked.tags.include?(target_tag)
    end
  end

  def fork_attachments
    if @source.image.attached?
      @forked.image.attach(@source.image.blob)
    end

    @source.images.each do |img|
      @forked.images.attach(img.blob)
    end
  end
end

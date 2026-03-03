# frozen_string_literal: true

module RecipeParamsPermittable
  extend ActiveSupport::Concern

  PERMITTED_RECIPE_PARAMS = [
    :title,
    :description,
    :category,
    :source,
    :servings,
    :prep_time,
    :cook_time,
    :rating,
    { ingredients_attributes: %i[id name quantity unit display_order _destroy],
      instructions_attributes: %i[id step_number instruction _destroy],
      nutrition_data_attributes: %i[
        id calories fat protein carbs fiber
        sodium potassium magnesium _destroy
      ],
      tips_attributes: %i[id tip _destroy] }
  ].freeze

  private

  def permitted_recipe_params(*extra)
    params.require(:recipe).permit(*PERMITTED_RECIPE_PARAMS, *extra)
  end
end

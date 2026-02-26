# frozen_string_literal: true

class RecipeGenerateJob < AiBaseJob
  private

  def execute(description:, diet_name: nil)
    update_progress(10)
    generator = RecipeImport::AiGenerator.new(description, diet_name: diet_name)

    update_progress(30)
    recipe_data = generator.generate

    update_progress(90)
    recipe_data.merge(method_used: "ai_generated")
  end
end

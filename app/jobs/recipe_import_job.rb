# frozen_string_literal: true

class RecipeImportJob < AiBaseJob
  private

  def execute(url:)
    update_progress(10)
    importer = RecipeImport::UrlImporter.new(url)

    update_progress(30)
    recipe_data = importer.import

    update_progress(90)
    recipe_data.merge(method_used: importer.method_used.to_s)
  end
end

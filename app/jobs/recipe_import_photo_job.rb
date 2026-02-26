# frozen_string_literal: true

class RecipeImportPhotoJob < AiBaseJob
  private

  def execute(blob_ids:)
    update_progress(10)
    blobs = ActiveStorage::Blob.where(id: blob_ids)

    update_progress(20)
    extractor = RecipeImport::PhotoExtractor.new(blobs.to_a)

    update_progress(40)
    recipe_data = extractor.extract

    update_progress(90)
    recipe_data.merge(method_used: "photo")
  end
end

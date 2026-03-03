# frozen_string_literal: true

module RecipeImport
  class PhotoExtractor
    include RecipeImport::Normalizer

    SYSTEM_PROMPT = <<~PROMPT
      You are a recipe extraction assistant. Given one or more photos of a recipe
      (cookbook page, handwritten card, screenshot, etc.), extract the recipe information
      and return it using the provided tool.
      If the images do not contain a recipe, return empty values.
      For ingredients, include the full text as written (e.g. "2 cups almond flour").
      For instructions, extract each step as a separate item.
      Handle rotated or slightly skewed text gracefully.
      If the recipe spans multiple images, combine the information from all images.
    PROMPT

    RECIPE_TOOL = RecipeImport::AiExtractor::RECIPE_TOOL

    MAX_IMAGE_SIZE = 10.megabytes
    SUPPORTED_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

    def initialize(images, ai_client: nil)
      @images = images.is_a?(Array) ? images : [ images ]
      @ai_client = ai_client || Ai::Client.new
    end

    def extract
      content = build_content_blocks
      raise ExtractionError, "No valid images provided" if content.empty?

      result = @ai_client.chat_with_tools(
        messages: [ { role: "user", content: content } ],
        tools: [ RECIPE_TOOL ],
        system: SYSTEM_PROMPT,
        max_tokens: 4096,
        feature: "recipe_photo_import"
      )

      normalize(result[:input])
    end

    class ExtractionError < StandardError; end

    private

    def build_content_blocks
      blocks = @images.filter_map { |image| image_block(image) }
      blocks << { type: "text", text: "Extract the recipe from these images." } if blocks.any?
      blocks
    end

    def image_block(image)
      data, media_type = encode_image(image)
      return nil unless data

      {
        type: "image",
        source: {
          type: "base64",
          media_type: media_type,
          data: data
        }
      }
    end

    def encode_image(image)
      case image
      when ActiveStorage::Blob
        return nil unless valid_blob?(image)
        [ Base64.strict_encode64(image.download), image.content_type ]
      when Hash
        # Direct base64 data: { data: "...", content_type: "image/jpeg" }
        [ image[:data], image[:content_type] ]
      end
    end

    def valid_blob?(blob)
      SUPPORTED_CONTENT_TYPES.include?(blob.content_type) && blob.byte_size <= MAX_IMAGE_SIZE
    end
  end
end

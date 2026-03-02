# frozen_string_literal: true

require "test_helper"

class RecipeImport::PhotoExtractorTest < ActiveSupport::TestCase
  # Fake AI client that returns a predetermined tool_use result
  class FakeAiClient
    attr_reader :last_call

    def initialize(tool_input)
      @tool_input = tool_input
    end

    def chat_with_tools(messages:, tools:, system: nil, max_tokens: 4096, feature: nil)
      @last_call = { messages: messages, tools: tools, system: system, max_tokens: max_tokens }
      { name: "extract_recipe", input: @tool_input }
    end
  end

  test "extracts recipe data from image via AI" do
    fake_client = FakeAiClient.new({
      "title" => "Grandma's Keto Cookies",
      "description" => "Low carb cookies from a handwritten recipe card",
      "servings" => 24,
      "prep_time" => 15,
      "cook_time" => 12,
      "ingredients" => [ "2 cups almond flour", "1/2 cup butter", "1 egg" ],
      "instructions" => [ "Mix dry ingredients", "Add wet ingredients", "Bake at 350F" ],
      "calories" => 95.0,
      "fat" => 8.0,
      "protein" => 3.0,
      "carbs" => 1.5
    })

    image = { data: Base64.strict_encode64("fake image data"), content_type: "image/jpeg" }
    extractor = RecipeImport::PhotoExtractor.new(image, ai_client: fake_client)
    result = extractor.extract

    assert_equal "Grandma's Keto Cookies", result[:title]
    assert_equal 24, result[:servings]
    assert_equal 3, result[:ingredients].length
    assert_equal 3, result[:instructions].length
    assert_equal 1, result[:instructions].first[:step_number]
    assert_equal "Mix dry ingredients", result[:instructions].first[:instruction]
    assert_equal 95.0, result[:nutrition][:calories]
  end

  test "handles multiple images" do
    fake_client = FakeAiClient.new({
      "title" => "Multi-Page Recipe",
      "ingredients" => [ "flour", "sugar" ],
      "instructions" => [ "Mix", "Bake" ]
    })

    images = [
      { data: Base64.strict_encode64("page 1"), content_type: "image/jpeg" },
      { data: Base64.strict_encode64("page 2"), content_type: "image/png" }
    ]
    extractor = RecipeImport::PhotoExtractor.new(images, ai_client: fake_client)
    result = extractor.extract

    assert_equal "Multi-Page Recipe", result[:title]

    # Verify both images were sent in the message
    content = fake_client.last_call[:messages].first[:content]
    image_blocks = content.select { |b| b[:type] == "image" }
    assert_equal 2, image_blocks.length
  end

  test "sends text prompt after images" do
    fake_client = FakeAiClient.new({
      "title" => "Test",
      "ingredients" => [ "water" ],
      "instructions" => [ "boil" ]
    })

    image = { data: Base64.strict_encode64("data"), content_type: "image/jpeg" }
    RecipeImport::PhotoExtractor.new(image, ai_client: fake_client).extract

    content = fake_client.last_call[:messages].first[:content]
    text_block = content.find { |b| b[:type] == "text" }
    assert_not_nil text_block
    assert_includes text_block[:text], "Extract the recipe"
  end

  test "raises ExtractionError when no valid images" do
    fake_client = FakeAiClient.new({})

    error = assert_raises(RecipeImport::PhotoExtractor::ExtractionError) do
      RecipeImport::PhotoExtractor.new([], ai_client: fake_client).extract
    end
    assert_match(/No valid images/, error.message)
  end

  test "handles missing nutrition gracefully" do
    fake_client = FakeAiClient.new({
      "title" => "Simple Recipe",
      "ingredients" => [ "1 egg" ],
      "instructions" => [ "Cook it" ]
    })

    image = { data: Base64.strict_encode64("data"), content_type: "image/jpeg" }
    result = RecipeImport::PhotoExtractor.new(image, ai_client: fake_client).extract

    assert_nil result[:nutrition]
  end

  test "normalizes instructions with step numbers" do
    fake_client = FakeAiClient.new({
      "title" => "Test",
      "ingredients" => [ "water" ],
      "instructions" => [ "Step A", "Step B", "Step C" ]
    })

    image = { data: Base64.strict_encode64("data"), content_type: "image/jpeg" }
    result = RecipeImport::PhotoExtractor.new(image, ai_client: fake_client).extract

    assert_equal 1, result[:instructions][0][:step_number]
    assert_equal 2, result[:instructions][1][:step_number]
    assert_equal 3, result[:instructions][2][:step_number]
  end

  test "reuses RECIPE_TOOL from AiExtractor" do
    assert_equal RecipeImport::AiExtractor::RECIPE_TOOL, RecipeImport::PhotoExtractor::RECIPE_TOOL
  end

  test "wraps single image in array" do
    fake_client = FakeAiClient.new({
      "title" => "Test",
      "ingredients" => [ "water" ],
      "instructions" => [ "boil" ]
    })

    image = { data: Base64.strict_encode64("data"), content_type: "image/jpeg" }
    result = RecipeImport::PhotoExtractor.new(image, ai_client: fake_client).extract

    assert_equal "Test", result[:title]
  end

  test "supports ActiveStorage blobs" do
    fake_client = FakeAiClient.new({
      "title" => "Blob Recipe",
      "ingredients" => [ "flour" ],
      "instructions" => [ "mix" ]
    })

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake jpeg data"),
      filename: "recipe.jpg",
      content_type: "image/jpeg"
    )

    result = RecipeImport::PhotoExtractor.new(blob, ai_client: fake_client).extract
    assert_equal "Blob Recipe", result[:title]

    # Verify the blob data was base64 encoded in the message
    content = fake_client.last_call[:messages].first[:content]
    image_block = content.find { |b| b[:type] == "image" }
    assert_equal "image/jpeg", image_block[:source][:media_type]
    assert_equal Base64.strict_encode64("fake jpeg data"), image_block[:source][:data]
  end

  test "skips blobs with unsupported content types" do
    fake_client = FakeAiClient.new({})

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake data"),
      filename: "recipe.pdf",
      content_type: "application/pdf"
    )

    error = assert_raises(RecipeImport::PhotoExtractor::ExtractionError) do
      RecipeImport::PhotoExtractor.new(blob, ai_client: fake_client).extract
    end
    assert_match(/No valid images/, error.message)
  end
end

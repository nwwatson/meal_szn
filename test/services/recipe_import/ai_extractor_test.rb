# frozen_string_literal: true

require "test_helper"

class RecipeImport::AiExtractorTest < ActiveSupport::TestCase
  # Fake AI client that returns a predetermined tool_use result
  class FakeAiClient
    attr_reader :last_call

    def initialize(tool_input)
      @tool_input = tool_input
    end

    def chat_with_tools(messages:, tools:, system: nil, max_tokens: 4096)
      @last_call = { messages: messages, tools: tools, system: system, max_tokens: max_tokens }
      { name: "extract_recipe", input: @tool_input }
    end
  end

  test "extracts recipe data via AI client" do
    fake_client = FakeAiClient.new({
      "title" => "Keto Pancakes",
      "description" => "Fluffy low-carb pancakes",
      "servings" => 4,
      "prep_time" => 5,
      "cook_time" => 10,
      "ingredients" => [ "2 oz cream cheese", "2 eggs", "1 tbsp almond flour" ],
      "instructions" => [ "Mix ingredients", "Cook on medium heat", "Flip and serve" ],
      "calories" => 120.0,
      "fat" => 9.0,
      "protein" => 6.0,
      "carbs" => 2.0
    })

    extractor = RecipeImport::AiExtractor.new("Some page text about pancakes", ai_client: fake_client)
    result = extractor.extract

    assert_equal "Keto Pancakes", result[:title]
    assert_equal "Fluffy low-carb pancakes", result[:description]
    assert_equal 4, result[:servings]
    assert_equal 3, result[:ingredients].length
    assert_equal 3, result[:instructions].length
    assert_equal 1, result[:instructions].first[:step_number]
    assert_equal "Mix ingredients", result[:instructions].first[:instruction]
    assert_equal 120.0, result[:nutrition][:calories]
    assert_equal 9.0, result[:nutrition][:fat]
  end

  test "normalizes instructions with step numbers" do
    fake_client = FakeAiClient.new({
      "title" => "Test",
      "ingredients" => [ "water" ],
      "instructions" => [ "Step A", "Step B" ]
    })

    result = RecipeImport::AiExtractor.new("text", ai_client: fake_client).extract

    assert_equal 1, result[:instructions][0][:step_number]
    assert_equal 2, result[:instructions][1][:step_number]
  end

  test "handles missing nutrition gracefully" do
    fake_client = FakeAiClient.new({
      "title" => "Simple Recipe",
      "ingredients" => [ "1 egg" ],
      "instructions" => [ "Cook it" ]
    })

    result = RecipeImport::AiExtractor.new("text", ai_client: fake_client).extract

    assert_nil result[:nutrition]
  end

  test "truncates long page text" do
    long_text = "x" * 20_000
    fake_client = FakeAiClient.new({
      "title" => "Test",
      "ingredients" => [ "water" ],
      "instructions" => [ "boil" ]
    })

    RecipeImport::AiExtractor.new(long_text, ai_client: fake_client).extract

    # The message content should contain truncated text
    message_content = fake_client.last_call[:messages].first[:content]
    assert message_content.length < 20_000
  end

  test "RECIPE_TOOL has required fields" do
    tool = RecipeImport::AiExtractor::RECIPE_TOOL
    assert_equal "extract_recipe", tool[:name]
    assert_includes tool[:input_schema][:required], "title"
    assert_includes tool[:input_schema][:required], "ingredients"
    assert_includes tool[:input_schema][:required], "instructions"
  end
end

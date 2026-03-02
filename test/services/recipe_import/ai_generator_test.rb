# frozen_string_literal: true

require "test_helper"

class RecipeImport::AiGeneratorTest < ActiveSupport::TestCase
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

  test "generates a full recipe from description" do
    fake_client = FakeAiClient.new({
      "title" => "Bacon Wrapped Chicken Thighs",
      "description" => "Juicy chicken thighs wrapped in crispy bacon",
      "servings" => 4,
      "prep_time" => 15,
      "cook_time" => 35,
      "ingredients" => [ "4 chicken thighs", "8 slices bacon", "4 oz cream cheese" ],
      "instructions" => [ "Preheat oven to 400F", "Stuff chicken with cream cheese", "Wrap with bacon", "Bake 35 minutes" ],
      "calories" => 450.0,
      "fat" => 32.0,
      "protein" => 38.0,
      "carbs" => 1.0,
      "fiber" => 0.0
    })

    generator = RecipeImport::AiGenerator.new("bacon wrapped chicken thighs with cream cheese", ai_client: fake_client)
    result = generator.generate

    assert_equal "Bacon Wrapped Chicken Thighs", result[:title]
    assert_equal 4, result[:servings]
    assert_equal 15, result[:prep_time]
    assert_equal 35, result[:cook_time]
    assert_equal 3, result[:ingredients].length
    assert_equal 4, result[:instructions].length
    assert_equal 1, result[:instructions].first[:step_number]
    assert_equal "Preheat oven to 400F", result[:instructions].first[:instruction]
    assert_equal 450.0, result[:nutrition][:calories]
    assert_equal 32.0, result[:nutrition][:fat]
  end

  test "includes diet name in system prompt when provided" do
    fake_client = FakeAiClient.new({
      "title" => "Keto Pancakes",
      "ingredients" => [ "almond flour" ],
      "instructions" => [ "mix and cook" ]
    })

    RecipeImport::AiGenerator.new("pancakes", diet_name: "Ketogenic (Keto)", ai_client: fake_client).generate

    system = fake_client.last_call[:system]
    assert_includes system, "Ketogenic (Keto)"
    assert_includes system, "dietary approach"
  end

  test "omits diet context when diet_name is nil" do
    fake_client = FakeAiClient.new({
      "title" => "Pancakes",
      "ingredients" => [ "flour" ],
      "instructions" => [ "cook" ]
    })

    RecipeImport::AiGenerator.new("pancakes", ai_client: fake_client).generate

    system = fake_client.last_call[:system]
    assert_not_includes system, "IMPORTANT"
    assert_not_includes system, "dietary approach"
  end

  test "sends description in user message" do
    fake_client = FakeAiClient.new({
      "title" => "Test",
      "ingredients" => [ "water" ],
      "instructions" => [ "boil" ]
    })

    RecipeImport::AiGenerator.new("spicy tuna bowl", ai_client: fake_client).generate

    message = fake_client.last_call[:messages].first[:content]
    assert_includes message, "spicy tuna bowl"
  end

  test "handles missing nutrition gracefully" do
    fake_client = FakeAiClient.new({
      "title" => "Simple Dish",
      "ingredients" => [ "1 egg" ],
      "instructions" => [ "Cook it" ]
    })

    result = RecipeImport::AiGenerator.new("egg", ai_client: fake_client).generate
    assert_nil result[:nutrition]
  end

  test "normalizes instructions with step numbers" do
    fake_client = FakeAiClient.new({
      "title" => "Test",
      "ingredients" => [ "water" ],
      "instructions" => [ "Step A", "Step B", "Step C" ]
    })

    result = RecipeImport::AiGenerator.new("test", ai_client: fake_client).generate
    assert_equal 1, result[:instructions][0][:step_number]
    assert_equal 2, result[:instructions][1][:step_number]
    assert_equal 3, result[:instructions][2][:step_number]
  end

  test "reuses RECIPE_TOOL from AiExtractor" do
    assert_equal RecipeImport::AiExtractor::RECIPE_TOOL, RecipeImport::AiGenerator::RECIPE_TOOL
  end
end

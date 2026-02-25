# frozen_string_literal: true

require "test_helper"

class Ai::ClientTest < ActiveSupport::TestCase
  # Testable subclass that intercepts the Anthropic API call
  class TestableClient < Ai::Client
    attr_accessor :stub_responses, :call_count, :last_params

    def initialize(stub_responses:, model: nil)
      @stub_responses = Array(stub_responses)
      @call_count = 0
      @last_params = nil
      super(api_key: "test-key", model: model)
    end

    private

    def anthropic_client
      @fake_client ||= FakeAnthropicClient.new(self)
    end
  end

  # Minimal fake that mimics Anthropic::Client.messages.create
  class FakeAnthropicClient
    def initialize(testable_client)
      @testable_client = testable_client
    end

    def messages
      self
    end

    def create(**params)
      @testable_client.last_params = params
      index = @testable_client.call_count
      @testable_client.call_count += 1
      response = @testable_client.stub_responses[index] || @testable_client.stub_responses.last

      raise response if response.is_a?(Exception)

      response
    end
  end

  # Simple struct to mimic Anthropic response content blocks
  TextBlock = Struct.new(:type, :text, keyword_init: true)
  ToolUseBlock = Struct.new(:type, :name, :input, keyword_init: true)

  # Wraps a hash to respond to .to_h (like Anthropic tool input)
  class FakeToolInput
    def initialize(hash)
      @hash = hash
    end

    def to_h
      @hash
    end
  end

  # Simple response object
  class FakeResponse
    attr_reader :content

    def initialize(content:)
      @content = content
    end
  end

  # --- Initialization ---

  test "raises AuthenticationError when API key is missing" do
    assert_raises(Ai::Client::AuthenticationError) do
      Ai::Client.new(api_key: nil)
    end
  end

  test "initializes with provided API key" do
    client = Ai::Client.new(api_key: "test-key")
    assert_not_nil client
  end

  # --- chat ---

  test "chat returns text content from response" do
    response = FakeResponse.new(content: [
      TextBlock.new(type: "text", text: "Hello! How can I help?")
    ])

    client = TestableClient.new(stub_responses: response)
    result = client.chat(messages: [ { role: "user", content: "Hi" } ])

    assert_equal "Hello! How can I help?", result
  end

  test "chat concatenates multiple text blocks" do
    response = FakeResponse.new(content: [
      TextBlock.new(type: "text", text: "Part one. "),
      TextBlock.new(type: "text", text: "Part two.")
    ])

    client = TestableClient.new(stub_responses: response)
    result = client.chat(messages: [ { role: "user", content: "Hi" } ])

    assert_equal "Part one. Part two.", result
  end

  test "chat passes system prompt when provided" do
    response = FakeResponse.new(content: [
      TextBlock.new(type: "text", text: "response")
    ])

    client = TestableClient.new(stub_responses: response)
    client.chat(messages: [ { role: "user", content: "Hi" } ], system: "You are a chef.")

    assert_equal "You are a chef.", client.last_params[:system]
  end

  test "chat omits system key when not provided" do
    response = FakeResponse.new(content: [
      TextBlock.new(type: "text", text: "response")
    ])

    client = TestableClient.new(stub_responses: response)
    client.chat(messages: [ { role: "user", content: "Hi" } ])

    assert_not client.last_params.key?(:system)
  end

  test "chat uses default max_tokens of 1024" do
    response = FakeResponse.new(content: [
      TextBlock.new(type: "text", text: "response")
    ])

    client = TestableClient.new(stub_responses: response)
    client.chat(messages: [ { role: "user", content: "Hi" } ])

    assert_equal 1024, client.last_params[:max_tokens]
  end

  # --- chat_with_tools ---

  test "chat_with_tools returns parsed tool use block" do
    tool_input = FakeToolInput.new({ "recipe_name" => "Keto Pancakes", "calories" => 350 })
    response = FakeResponse.new(content: [
      ToolUseBlock.new(type: "tool_use", name: "generate_recipe", input: tool_input)
    ])

    tools = [ {
      name: "generate_recipe",
      description: "Generate a recipe",
      input_schema: {
        type: "object",
        properties: { recipe_name: { type: "string" }, calories: { type: "integer" } },
        required: [ "recipe_name" ]
      }
    } ]

    client = TestableClient.new(stub_responses: response)
    result = client.chat_with_tools(
      messages: [ { role: "user", content: "Give me a keto pancake recipe" } ],
      tools: tools
    )

    assert_equal "generate_recipe", result[:name]
    assert_equal "Keto Pancakes", result[:input]["recipe_name"]
    assert_equal 350, result[:input]["calories"]
  end

  test "chat_with_tools sends tool_choice any" do
    tool_input = FakeToolInput.new({})
    response = FakeResponse.new(content: [
      ToolUseBlock.new(type: "tool_use", name: "test_tool", input: tool_input)
    ])

    client = TestableClient.new(stub_responses: response)
    client.chat_with_tools(
      messages: [ { role: "user", content: "test" } ],
      tools: [ { name: "test_tool", description: "test", input_schema: { type: "object", properties: {} } } ]
    )

    assert_equal({ type: "any" }, client.last_params[:tool_choice])
  end

  test "chat_with_tools raises ApiError when no tool_use block in response" do
    response = FakeResponse.new(content: [
      TextBlock.new(type: "text", text: "I can't use tools")
    ])

    client = TestableClient.new(stub_responses: response)

    error = assert_raises(Ai::Client::ApiError) do
      client.chat_with_tools(
        messages: [ { role: "user", content: "test" } ],
        tools: [ { name: "test_tool", description: "test", input_schema: { type: "object", properties: {} } } ]
      )
    end

    assert_match(/No tool_use block/, error.message)
  end

  # --- vision ---

  test "vision returns text response for image messages" do
    response = FakeResponse.new(content: [
      TextBlock.new(type: "text", text: "I see a delicious steak")
    ])

    client = TestableClient.new(stub_responses: response)
    messages = [ {
      role: "user",
      content: [
        { type: "image", source: { type: "base64", media_type: "image/jpeg", data: "abc123" } },
        { type: "text", text: "What food is in this image?" }
      ]
    } ]

    result = client.vision(messages: messages)
    assert_equal "I see a delicious steak", result
  end

  # --- Error handling and retries ---

  test "retries on rate limit error and eventually raises" do
    rate_limit_error = Anthropic::Errors::RateLimitError.new(
      url: URI("https://api.anthropic.com/v1/messages"),
      status: 429,
      headers: {},
      body: "rate limited",
      request: nil,
      response: nil
    )

    client = TestableClient.new(stub_responses: [ rate_limit_error, rate_limit_error, rate_limit_error ])
    client.define_singleton_method(:sleep) { |_| } # no-op sleep

    assert_raises(Ai::Client::RateLimitError) do
      client.chat(messages: [ { role: "user", content: "Hi" } ])
    end

    assert_equal 3, client.call_count
  end

  test "retries on server error and succeeds on final attempt" do
    server_error = Anthropic::Errors::InternalServerError.new(
      url: URI("https://api.anthropic.com/v1/messages"),
      status: 500,
      headers: {},
      body: "server error",
      request: nil,
      response: nil
    )
    success = FakeResponse.new(content: [
      TextBlock.new(type: "text", text: "Success after retry")
    ])

    client = TestableClient.new(stub_responses: [ server_error, server_error, success ])
    client.define_singleton_method(:sleep) { |_| }

    result = client.chat(messages: [ { role: "user", content: "Hi" } ])

    assert_equal "Success after retry", result
    assert_equal 3, client.call_count
  end

  test "retries on timeout and eventually raises" do
    timeout_error = Anthropic::Errors::APITimeoutError.new(
      url: URI("https://api.anthropic.com/v1/messages"),
      request: nil,
      response: nil
    )

    client = TestableClient.new(stub_responses: [ timeout_error, timeout_error, timeout_error ])
    client.define_singleton_method(:sleep) { |_| }

    assert_raises(Ai::Client::TimeoutError) do
      client.chat(messages: [ { role: "user", content: "Hi" } ])
    end

    assert_equal 3, client.call_count
  end

  test "does not retry authentication errors" do
    auth_error = Anthropic::Errors::AuthenticationError.new(
      url: URI("https://api.anthropic.com/v1/messages"),
      status: 401,
      headers: {},
      body: "invalid key",
      request: nil,
      response: nil
    )

    client = TestableClient.new(stub_responses: [ auth_error ])

    assert_raises(Ai::Client::AuthenticationError) do
      client.chat(messages: [ { role: "user", content: "Hi" } ])
    end

    assert_equal 1, client.call_count
  end

  test "wraps generic API errors" do
    bad_request = Anthropic::Errors::BadRequestError.new(
      url: URI("https://api.anthropic.com/v1/messages"),
      status: 400,
      headers: {},
      body: "bad request",
      request: nil,
      response: nil
    )

    client = TestableClient.new(stub_responses: [ bad_request ])

    error = assert_raises(Ai::Client::ApiError) do
      client.chat(messages: [ { role: "user", content: "Hi" } ])
    end

    assert_match(/400/, error.message)
    assert_equal 1, client.call_count
  end

  # --- Model configuration ---

  test "uses default model from initializer" do
    response = FakeResponse.new(content: [
      TextBlock.new(type: "text", text: "response")
    ])

    client = TestableClient.new(stub_responses: response)
    client.chat(messages: [ { role: "user", content: "Hi" } ])

    assert_equal "claude-sonnet-4-20250514", client.last_params[:model]
  end

  test "uses custom model when provided" do
    response = FakeResponse.new(content: [
      TextBlock.new(type: "text", text: "response")
    ])

    client = TestableClient.new(stub_responses: response, model: "claude-haiku-4-5-20251001")
    client.chat(messages: [ { role: "user", content: "Hi" } ])

    assert_equal "claude-haiku-4-5-20251001", client.last_params[:model]
  end
end

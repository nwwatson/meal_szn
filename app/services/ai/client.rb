# frozen_string_literal: true

module Ai
  class Client
    class Error < StandardError; end
    class ApiError < Error; end
    class RateLimitError < ApiError; end
    class TimeoutError < ApiError; end
    class AuthenticationError < ApiError; end

    MAX_RETRIES = 3
    RETRY_DELAYS = [ 1, 2, 4 ].freeze

    def initialize(api_key: nil, model: nil)
      @api_key = api_key || Rails.application.credentials.dig(:ai, :anthropic, :api_key)
      @model = model || Ai.default_model

      raise AuthenticationError, "Anthropic API key is not configured" if @api_key.blank?
    end

    # Basic message completion
    #
    # @param messages [Array<Hash>] Conversation messages, e.g. [{role: "user", content: "Hello"}]
    # @param system [String, nil] Optional system prompt
    # @param max_tokens [Integer] Maximum tokens to generate
    # @return [String] The assistant's text response
    def chat(messages:, system: nil, max_tokens: 1024)
      params = build_params(messages:, system:, max_tokens:)
      response = with_retries { anthropic_client.messages.create(**params) }
      extract_text(response)
    end

    # Message completion with tool use for structured JSON output
    #
    # @param messages [Array<Hash>] Conversation messages
    # @param tools [Array<Hash>] Tool definitions with name, description, input_schema
    # @param system [String, nil] Optional system prompt
    # @param max_tokens [Integer] Maximum tokens to generate
    # @return [Hash] Parsed tool input from the model's tool_use response
    def chat_with_tools(messages:, tools:, system: nil, max_tokens: 4096)
      params = build_params(messages:, system:, max_tokens:)
      params[:tools] = tools
      params[:tool_choice] = { type: "any" }

      response = with_retries { anthropic_client.messages.create(**params) }
      extract_tool_use(response)
    end

    # Vision-capable message completion (images + text)
    #
    # @param messages [Array<Hash>] Messages with image content blocks
    # @param system [String, nil] Optional system prompt
    # @param max_tokens [Integer] Maximum tokens to generate
    # @return [String] The assistant's text response
    def vision(messages:, system: nil, max_tokens: 1024)
      chat(messages:, system:, max_tokens:)
    end

    private

    def anthropic_client
      @anthropic_client ||= Anthropic::Client.new(api_key: @api_key)
    end

    def build_params(messages:, system: nil, max_tokens:)
      params = {
        model: @model,
        max_tokens: max_tokens,
        messages: messages
      }
      params[:system] = system if system.present?
      params
    end

    def with_retries(&block)
      attempts = 0
      begin
        attempts += 1
        yield
      rescue Anthropic::Errors::RateLimitError, Anthropic::Errors::InternalServerError => e
        raise RateLimitError, "Rate limit exceeded: #{e.message}" if attempts >= MAX_RETRIES
        sleep RETRY_DELAYS[attempts - 1]
        retry
      rescue Anthropic::Errors::APITimeoutError => e
        raise TimeoutError, "Request timed out: #{e.message}" if attempts >= MAX_RETRIES
        sleep RETRY_DELAYS[attempts - 1]
        retry
      rescue Anthropic::Errors::AuthenticationError => e
        raise AuthenticationError, "Authentication failed: #{e.message}"
      rescue Anthropic::Errors::APIError => e
        raise ApiError, "API error (#{e.status}): #{e.message}"
      end
    end

    def extract_text(response)
      response.content
        .select { |block| block.type.to_s == "text" }
        .map(&:text)
        .join
    end

    def extract_tool_use(response)
      tool_block = response.content.find { |block| block.type.to_s == "tool_use" }
      raise ApiError, "No tool_use block in response" unless tool_block

      { name: tool_block.name, input: tool_block.input.to_h }
    end
  end
end

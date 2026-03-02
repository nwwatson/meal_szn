require "test_helper"

class Ai::InstrumentationTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    Current.account = @account
  end

  teardown do
    Current.account = nil
  end

  test "records metric from notification event" do
    payload = {
      model: "claude-haiku-4-5-20251001",
      method_name: "chat_with_tools",
      feature: "meal_plan_generation",
      duration_ms: 1500.3,
      usage: {
        input_tokens: 500,
        output_tokens: 200,
        cache_creation_input_tokens: 0,
        cache_read_input_tokens: 1200
      },
      error: nil
    }

    assert_difference "AiRequestMetric.count" do
      ActiveSupport::Notifications.instrument("request.ai_client", payload)
    end

    metric = AiRequestMetric.order(created_at: :desc).first
    assert_equal @account.id, metric.account_id
    assert_equal "meal_plan_generation", metric.feature
    assert_equal "claude-haiku-4-5-20251001", metric.model
    assert_equal "chat_with_tools", metric.method_name
    assert_equal 500, metric.input_tokens
    assert_equal 200, metric.output_tokens
    assert_equal 0, metric.cache_creation_input_tokens
    assert_equal 1200, metric.cache_read_input_tokens
    assert_in_delta 1500.3, metric.duration_ms, 0.1
    assert metric.cache_hit?
    assert_nil metric.error_class
  end

  test "records error details" do
    error = Ai::Client::RateLimitError.new("Rate limit exceeded")
    payload = {
      model: "claude-sonnet-4-20250514",
      method_name: "chat",
      feature: "recipe_import",
      duration_ms: 300.0,
      usage: {},
      error: error
    }

    assert_difference "AiRequestMetric.count" do
      ActiveSupport::Notifications.instrument("request.ai_client", payload)
    end

    metric = AiRequestMetric.order(created_at: :desc).first
    assert_equal "Ai::Client::RateLimitError", metric.error_class
    assert_equal "Rate limit exceeded", metric.error_message
    assert_not metric.cache_hit?
  end

  test "records metric without account context" do
    Current.account = nil

    payload = {
      model: "claude-sonnet-4-20250514",
      method_name: "chat_with_tools",
      feature: "recipe_import",
      duration_ms: 2000.0,
      usage: { input_tokens: 1000, output_tokens: 300, cache_creation_input_tokens: 0, cache_read_input_tokens: 0 },
      error: nil
    }

    assert_difference "AiRequestMetric.count" do
      ActiveSupport::Notifications.instrument("request.ai_client", payload)
    end

    metric = AiRequestMetric.order(created_at: :desc).first
    assert_nil metric.account_id
  end

  test "cache_hit is false when no cache_read_input_tokens" do
    payload = {
      model: "claude-haiku-4-5-20251001",
      method_name: "chat_with_tools",
      feature: "meal_plan_generation",
      duration_ms: 2500.0,
      usage: { input_tokens: 2000, output_tokens: 300, cache_creation_input_tokens: 1500, cache_read_input_tokens: 0 },
      error: nil
    }

    ActiveSupport::Notifications.instrument("request.ai_client", payload)

    metric = AiRequestMetric.order(created_at: :desc).first
    assert_not metric.cache_hit?
  end

  test "handles empty usage gracefully" do
    payload = {
      model: "claude-sonnet-4-20250514",
      method_name: "chat",
      feature: "unknown",
      duration_ms: 100.0,
      usage: {},
      error: nil
    }

    assert_difference "AiRequestMetric.count" do
      ActiveSupport::Notifications.instrument("request.ai_client", payload)
    end

    metric = AiRequestMetric.order(created_at: :desc).first
    assert_equal 0, metric.input_tokens
    assert_equal 0, metric.output_tokens
  end
end

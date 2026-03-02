require "test_helper"

class AiRequestMetricTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
  end

  test "valid metric" do
    metric = AiRequestMetric.new(
      account: @account,
      feature: "meal_plan_generation",
      model: "claude-haiku-4-5-20251001",
      method_name: "chat_with_tools"
    )
    assert metric.valid?
  end

  test "requires feature" do
    metric = AiRequestMetric.new(feature: nil, model: "test", method_name: "chat")
    assert_not metric.valid?
    assert_includes metric.errors[:feature], "can't be blank"
  end

  test "requires model" do
    metric = AiRequestMetric.new(feature: "test", model: nil, method_name: "chat")
    assert_not metric.valid?
    assert_includes metric.errors[:model], "can't be blank"
  end

  test "requires method_name" do
    metric = AiRequestMetric.new(feature: "test", model: "test", method_name: nil)
    assert_not metric.valid?
    assert_includes metric.errors[:method_name], "can't be blank"
  end

  test "account is optional" do
    metric = AiRequestMetric.new(
      feature: "test",
      model: "test",
      method_name: "chat"
    )
    assert metric.valid?
  end

  test "total_input_tokens sums all input token types" do
    metric = ai_request_metrics(:cache_hit_metric)
    assert_equal 500 + 0 + 1500, metric.total_input_tokens
  end

  test "cache_savings_tokens returns cache_read_input_tokens" do
    hit = ai_request_metrics(:cache_hit_metric)
    assert_equal 1500, hit.cache_savings_tokens

    miss = ai_request_metrics(:cache_miss_metric)
    assert_equal 0, miss.cache_savings_tokens
  end

  test "estimated_cache_savings_ratio" do
    hit = ai_request_metrics(:cache_hit_metric)
    assert_in_delta 0.75, hit.estimated_cache_savings_ratio, 0.01

    miss = ai_request_metrics(:cache_miss_metric)
    assert_equal 0.0, miss.estimated_cache_savings_ratio
  end

  test "scopes filter correctly" do
    assert AiRequestMetric.cache_hits.all?(&:cache_hit?)
    assert AiRequestMetric.cache_misses.none?(&:cache_hit?)
    assert AiRequestMetric.successful.none? { |m| m.error_class.present? }
    assert AiRequestMetric.failed.all? { |m| m.error_class.present? }
  end

  test "cache_hit_rate class method" do
    rate = AiRequestMetric.cache_hit_rate(since: 25.hours.ago)
    # 1 hit out of 3 successful (cache_hit, cache_miss, recipe_import) = 33.3%
    assert_in_delta 33.3, rate, 0.1
  end

  test "cache_hit_rate returns 0 with no data" do
    assert_equal 0.0, AiRequestMetric.cache_hit_rate(since: 1.minute.ago)
  end

  test "total_tokens_used class method" do
    tokens = AiRequestMetric.total_tokens_used(since: 25.hours.ago)
    assert tokens[:input] > 0
    assert tokens[:output] > 0
    assert tokens[:cache_read] > 0
  end

  test "feature_breakdown groups by feature" do
    breakdown = AiRequestMetric.feature_breakdown(since: 25.hours.ago)
    features = breakdown.map(&:feature)
    assert_includes features, "meal_plan_generation"
    assert_includes features, "recipe_import"
  end

  test "for_feature scope" do
    results = AiRequestMetric.for_feature("meal_plan_generation")
    assert results.all? { |m| m.feature == "meal_plan_generation" }
  end

  test "since scope" do
    recent = AiRequestMetric.since(90.minutes.ago)
    assert recent.all? { |m| m.created_at >= 90.minutes.ago }
  end
end

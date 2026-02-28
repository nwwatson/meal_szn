require "test_helper"

class Ai::RateLimiterTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @cache = ActiveSupport::Cache::MemoryStore.new
    @limiter = Ai::RateLimiter.new(@account, cache_store: @cache)
  end

  test "allowed? returns true when under limit" do
    assert @limiter.allowed?(:recipe_import)
  end

  test "allowed? returns false when at limit" do
    Ai.rate_limits[:recipe_import][:limit].times do
      @limiter.increment!(:recipe_import)
    end

    assert_not @limiter.allowed?(:recipe_import)
  end

  test "increment! increases the count" do
    assert_equal 20, @limiter.remaining(:recipe_import)

    @limiter.increment!(:recipe_import)

    assert_equal 19, @limiter.remaining(:recipe_import)
  end

  test "remaining returns correct count" do
    assert_equal 20, @limiter.remaining(:recipe_import)

    5.times { @limiter.increment!(:recipe_import) }

    assert_equal 15, @limiter.remaining(:recipe_import)
  end

  test "remaining never goes below zero" do
    25.times { @limiter.increment!(:recipe_import) }

    assert_equal 0, @limiter.remaining(:recipe_import)
  end

  test "check! raises LimitExceededError when limit reached" do
    Ai.rate_limits[:recipe_import][:limit].times do
      @limiter.increment!(:recipe_import)
    end

    error = assert_raises(Ai::RateLimiter::LimitExceededError) do
      @limiter.check!(:recipe_import)
    end
    assert error.retry_after >= 0
  end

  test "check! increments and passes when under limit" do
    assert_nothing_raised do
      @limiter.check!(:recipe_import)
    end

    assert_equal 19, @limiter.remaining(:recipe_import)
  end

  test "retry_after returns positive seconds" do
    retry_seconds = @limiter.retry_after(:recipe_import)

    assert retry_seconds >= 0
    assert retry_seconds <= 3600
  end

  test "different features have independent limits" do
    Ai.rate_limits[:recipe_import][:limit].times do
      @limiter.increment!(:recipe_import)
    end

    assert_not @limiter.allowed?(:recipe_import)
    assert @limiter.allowed?(:meal_plan_generation)
    assert @limiter.allowed?(:quick_entry)
  end

  test "different accounts have independent limits" do
    other_account = accounts(:two)
    other_limiter = Ai::RateLimiter.new(other_account, cache_store: @cache)

    Ai.rate_limits[:recipe_import][:limit].times do
      @limiter.increment!(:recipe_import)
    end

    assert_not @limiter.allowed?(:recipe_import)
    assert other_limiter.allowed?(:recipe_import)
  end

  test "raises ArgumentError for unknown feature" do
    assert_raises(ArgumentError) do
      @limiter.allowed?(:nonexistent_feature)
    end
  end

  test "respects configurable limits" do
    original_limit = Ai.rate_limits[:recipe_import][:limit]
    Ai.rate_limits[:recipe_import][:limit] = 2

    2.times { @limiter.increment!(:recipe_import) }

    assert_not @limiter.allowed?(:recipe_import)
  ensure
    Ai.rate_limits[:recipe_import][:limit] = original_limit
  end

  test "meal_plan_generation has correct limit" do
    assert_equal 10, @limiter.remaining(:meal_plan_generation)

    10.times { @limiter.increment!(:meal_plan_generation) }

    assert_not @limiter.allowed?(:meal_plan_generation)
    assert_equal 0, @limiter.remaining(:meal_plan_generation)
  end

  test "quick_entry has correct limit" do
    assert_equal 30, @limiter.remaining(:quick_entry)
  end
end

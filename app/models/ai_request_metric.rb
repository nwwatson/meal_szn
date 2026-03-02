class AiRequestMetric < ApplicationRecord
  include Identifiable

  belongs_to :account, optional: true

  validates :feature, presence: true
  validates :model, presence: true
  validates :method_name, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_feature, ->(feature) { where(feature: feature) }
  scope :cache_hits, -> { where(cache_hit: true) }
  scope :cache_misses, -> { where(cache_hit: false) }
  scope :successful, -> { where(error_class: nil) }
  scope :failed, -> { where.not(error_class: nil) }
  scope :since, ->(time) { where("created_at >= ?", time) }

  FEATURES = %w[meal_plan_generation recipe_import recipe_photo_import recipe_quick_entry nutrition_calculation].freeze

  def total_input_tokens
    input_tokens + cache_creation_input_tokens + cache_read_input_tokens
  end

  def cache_savings_tokens
    cache_read_input_tokens
  end

  # Approximate cost savings based on Anthropic's cache pricing
  # Cache reads are 90% cheaper than regular input tokens
  def estimated_cache_savings_ratio
    return 0.0 if total_input_tokens.zero?
    cache_read_input_tokens.to_f / total_input_tokens
  end

  class << self
    def cache_hit_rate(since: 24.hours.ago)
      metrics = where("created_at >= ?", since).successful
      total = metrics.count
      return 0.0 if total.zero?
      hits = metrics.cache_hits.count
      (hits.to_f / total * 100).round(1)
    end

    def average_duration(since: 24.hours.ago)
      where("created_at >= ?", since)
        .successful
        .where.not(duration_ms: nil)
        .average(:duration_ms)
        &.round(0) || 0
    end

    def total_tokens_used(since: 24.hours.ago)
      metrics = where("created_at >= ?", since).successful
      {
        input: metrics.sum(:input_tokens),
        output: metrics.sum(:output_tokens),
        cache_creation: metrics.sum(:cache_creation_input_tokens),
        cache_read: metrics.sum(:cache_read_input_tokens)
      }
    end

    def feature_breakdown(since: 24.hours.ago)
      where("created_at >= ?", since)
        .successful
        .group(:feature)
        .select(
          "feature",
          "COUNT(*) as request_count",
          "SUM(input_tokens) as total_input",
          "SUM(output_tokens) as total_output",
          "SUM(cache_read_input_tokens) as total_cache_read",
          "SUM(cache_creation_input_tokens) as total_cache_creation",
          "AVG(duration_ms) as avg_duration"
        )
    end
  end
end

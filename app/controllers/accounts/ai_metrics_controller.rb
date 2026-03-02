class Accounts::AiMetricsController < ApplicationController
  before_action :require_admin!

  def index
    @period = params[:period] || "24h"
    @since = period_to_time(@period)

    @total_requests = metrics_scope.count
    @cache_hit_rate = AiRequestMetric.cache_hit_rate(since: @since)
    @avg_duration = AiRequestMetric.average_duration(since: @since)
    @tokens = AiRequestMetric.total_tokens_used(since: @since)
    @feature_breakdown = AiRequestMetric.feature_breakdown(since: @since)
    @error_count = metrics_scope.failed.count
    @recent = metrics_scope.recent.limit(25)
  end

  private

  def require_admin!
    unless Current.user&.has_role_at_least?(:admin)
      redirect_to account_root_path, alert: "Access denied."
    end
  end

  def metrics_scope
    Current.account.ai_request_metrics.since(@since)
  end

  def period_to_time(period)
    case period
    when "1h" then 1.hour.ago
    when "24h" then 24.hours.ago
    when "7d" then 7.days.ago
    when "30d" then 30.days.ago
    else 24.hours.ago
    end
  end
end

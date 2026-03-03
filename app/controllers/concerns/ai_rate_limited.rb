# frozen_string_literal: true

# Provides AI rate-limiting checks for controllers.
#
# Usage in API controllers:
#   before_action -> { check_ai_rate_limit!(:recipe_import) }, only: [:import_url, :import_photo]
#
# Usage in web controllers:
#   before_action -> { check_ai_rate_limit!(:quick_entry, redirect_path: quick_entry_recipes_path) },
#                 only: [:start_quick_entry]
#
module AiRateLimited
  extend ActiveSupport::Concern

  private

  def check_ai_rate_limit!(feature, redirect_path: nil)
    account = Current.account
    return unless account

    limiter = Ai::RateLimiter.new(account)

    if limiter.allowed?(feature)
      limiter.increment!(feature)
      return
    end

    retry_after = limiter.retry_after(feature)

    if api_request?
      response.set_header("Retry-After", retry_after.to_s)
      render json: {
        error: "Rate limit exceeded. Please try again later.",
        retry_after: retry_after
      }, status: :too_many_requests
    else
      redirect_to(redirect_path || request.referer || root_path,
        alert: "You've reached the limit for this feature. Please try again in #{humanize_seconds(retry_after)}.")
    end
  end

  def ai_rate_limiter
    account = Current.account
    @ai_rate_limiter ||= Ai::RateLimiter.new(account)
  end

  def api_request?
    request.path.include?("/api/") || request.format.json?
  end

  def humanize_seconds(seconds)
    if seconds >= 3600
      "#{(seconds / 3600.0).ceil} #{"hour".pluralize((seconds / 3600.0).ceil)}"
    elsif seconds >= 60
      "#{(seconds / 60.0).ceil} #{"minute".pluralize((seconds / 60.0).ceil)}"
    else
      "#{seconds} #{"second".pluralize(seconds)}"
    end
  end
end

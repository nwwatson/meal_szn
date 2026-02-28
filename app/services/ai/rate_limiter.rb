# frozen_string_literal: true

module Ai
  class RateLimiter
    class LimitExceededError < StandardError
      attr_reader :retry_after

      def initialize(message = "Rate limit exceeded", retry_after: 0)
        @retry_after = retry_after
        super(message)
      end
    end

    attr_reader :cache_store

    def initialize(account, cache_store: Rails.cache)
      @account = account
      @cache_store = cache_store
    end

    def allowed?(feature)
      config = config_for(feature)
      count = current_count(feature, config[:window])
      count < config[:limit]
    end

    def increment!(feature)
      config = config_for(feature)
      key = cache_key(feature, config[:window])
      count = @cache_store.read(key).to_i
      @cache_store.write(key, count + 1, expires_in: config[:window])
    end

    def check!(feature)
      unless allowed?(feature)
        raise LimitExceededError.new(
          "Rate limit exceeded for #{feature}",
          retry_after: retry_after(feature)
        )
      end
      increment!(feature)
    end

    def remaining(feature)
      config = config_for(feature)
      count = current_count(feature, config[:window])
      [ config[:limit] - count, 0 ].max
    end

    def retry_after(feature)
      config = config_for(feature)

      # Return seconds until the current window expires.
      # Since we use time-aligned buckets, calculate time to next bucket.
      window_seconds = config[:window].to_i
      bucket = Time.current.to_i / window_seconds
      bucket_end = (bucket + 1) * window_seconds
      [ bucket_end - Time.current.to_i, 0 ].max
    end

    private

    def config_for(feature)
      config = Ai.rate_limits[feature.to_sym]
      raise ArgumentError, "Unknown AI rate limit feature: #{feature}" unless config
      config
    end

    def current_count(feature, window)
      key = cache_key(feature, window)
      @cache_store.read(key).to_i
    end

    def cache_key(feature, window)
      window_seconds = window.to_i
      bucket = Time.current.to_i / window_seconds
      "ai_rate_limit:#{@account.id}:#{feature}:#{bucket}"
    end
  end
end

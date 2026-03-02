# frozen_string_literal: true

module Ai
  class Instrumentation
    def self.subscribe!
      ActiveSupport::Notifications.subscribe("request.ai_client") do |event|
        new.record(event)
      end
    end

    def record(event)
      payload = event.payload
      usage = payload[:usage] || {}
      error = payload[:error]

      cache_read = usage[:cache_read_input_tokens] || 0
      cache_creation = usage[:cache_creation_input_tokens] || 0
      cache_hit = cache_read > 0

      attrs = {
        account_id: Current.account&.id,
        feature: payload[:feature] || "unknown",
        model: payload[:model],
        method_name: payload[:method_name],
        input_tokens: usage[:input_tokens] || 0,
        output_tokens: usage[:output_tokens] || 0,
        cache_creation_input_tokens: cache_creation,
        cache_read_input_tokens: cache_read,
        duration_ms: payload[:duration_ms],
        cache_hit: cache_hit
      }

      if error
        attrs[:error_class] = error.class.name
        attrs[:error_message] = error.message.truncate(500)
      end

      AiRequestMetric.create!(attrs)

      log_metrics(attrs)
    rescue => e
      Rails.logger.error("[Ai::Instrumentation] Failed to record metric: #{e.message}")
    end

    private

    def log_metrics(attrs)
      log_data = {
        ai_request: true,
        feature: attrs[:feature],
        model: attrs[:model],
        method: attrs[:method_name],
        duration_ms: attrs[:duration_ms],
        input_tokens: attrs[:input_tokens],
        output_tokens: attrs[:output_tokens],
        cache_hit: attrs[:cache_hit],
        cache_read_tokens: attrs[:cache_read_input_tokens],
        cache_creation_tokens: attrs[:cache_creation_input_tokens]
      }
      log_data[:error] = attrs[:error_class] if attrs[:error_class]

      Rails.logger.info("[Ai::Instrumentation] #{log_data.to_json}")
    end
  end
end

# frozen_string_literal: true

# Per-account rate limits for AI-powered features.
# Each key maps to { limit:, window: } where window is an ActiveSupport::Duration.
# Override via environment variables (e.g., AI_RATE_LIMIT_RECIPE_IMPORT=50).

Ai.rate_limits = {
  recipe_import: {
    limit: ENV.fetch("AI_RATE_LIMIT_RECIPE_IMPORT", 20).to_i,
    window: 1.hour
  },
  meal_plan_generation: {
    limit: ENV.fetch("AI_RATE_LIMIT_MEAL_PLAN_GENERATION", 10).to_i,
    window: 1.hour
  },
  quick_entry: {
    limit: ENV.fetch("AI_RATE_LIMIT_QUICK_ENTRY", 30).to_i,
    window: 1.hour
  }
}

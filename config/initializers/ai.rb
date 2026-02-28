# frozen_string_literal: true

module Ai
  mattr_accessor :default_model, default: "claude-sonnet-4-20250514"
  mattr_accessor :meal_planning_model, default: "claude-haiku-4-5-20251001"
  mattr_accessor :rate_limits, default: {}
end

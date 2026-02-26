# frozen_string_literal: true

require "test_helper"

class RecipeGenerateJobTest < ActiveSupport::TestCase
  test "job is enqueued on ai queue" do
    assert_equal "ai", RecipeGenerateJob.new.queue_name
  end

  test "job inherits from AiBaseJob" do
    assert RecipeGenerateJob < AiBaseJob
  end
end

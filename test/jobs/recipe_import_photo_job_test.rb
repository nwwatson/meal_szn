# frozen_string_literal: true

require "test_helper"

class RecipeImportPhotoJobTest < ActiveSupport::TestCase
  test "job is enqueued on ai queue" do
    assert_equal "ai", RecipeImportPhotoJob.new.queue_name
  end

  test "job inherits from AiBaseJob" do
    assert RecipeImportPhotoJob < AiBaseJob
  end
end

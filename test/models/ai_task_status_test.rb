# frozen_string_literal: true

require "test_helper"
require "turbo/broadcastable/test_helper"

class AiTaskStatusTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper
  # --- Associations ---

  test "belongs to account" do
    task = ai_task_statuses(:pending_task)
    assert_equal accounts(:one), task.account
  end

  # --- Validations ---

  test "requires task_type" do
    task = AiTaskStatus.new(account: accounts(:one))
    assert_not task.valid?
    assert_includes task.errors[:task_type], "can't be blank"
  end

  test "requires progress_percentage between 0 and 100" do
    task = AiTaskStatus.new(account: accounts(:one), task_type: "test", progress_percentage: -1)
    assert_not task.valid?

    task.progress_percentage = 101
    assert_not task.valid?

    task.progress_percentage = 50
    assert task.valid?
  end

  test "generates UUID on create" do
    task = AiTaskStatus.create!(account: accounts(:one), task_type: "test")
    assert task.id.present?
    assert_match(/\A[0-9a-f-]{36}\z/, task.id)
  end

  test "defaults to pending status" do
    task = AiTaskStatus.create!(account: accounts(:one), task_type: "test")
    assert task.pending?
  end

  test "defaults to 0 progress" do
    task = AiTaskStatus.create!(account: accounts(:one), task_type: "test")
    assert_equal 0, task.progress_percentage
  end

  # --- Status transitions ---

  test "allows pending to processing" do
    task = ai_task_statuses(:pending_task)
    task.mark_processing!
    assert task.processing?
  end

  test "allows pending to failed" do
    task = ai_task_statuses(:pending_task)
    task.mark_failed!(error_message: "startup error")
    assert task.failed?
    assert_equal "startup error", task.error_message
  end

  test "allows processing to completed" do
    task = ai_task_statuses(:processing_task)
    task.mark_completed!(result: { recipe_id: "xyz" })
    assert task.completed?
    assert_equal({ "recipe_id" => "xyz" }, task.result)
    assert_equal 100, task.progress_percentage
  end

  test "allows processing to failed" do
    task = ai_task_statuses(:processing_task)
    task.mark_failed!(error_message: "API error")
    assert task.failed?
  end

  test "allows failed to pending (retry)" do
    task = ai_task_statuses(:failed_task)
    task.update!(status: :pending)
    assert task.pending?
  end

  test "prevents pending to completed" do
    task = ai_task_statuses(:pending_task)
    assert_raises(ActiveRecord::RecordInvalid) do
      task.update!(status: :completed)
    end
    assert_includes task.errors[:status], "cannot transition from pending to completed"
  end

  test "prevents completed to processing" do
    task = ai_task_statuses(:completed_task)
    assert_raises(ActiveRecord::RecordInvalid) do
      task.update!(status: :processing)
    end
  end

  test "prevents completed to pending" do
    task = ai_task_statuses(:completed_task)
    assert_raises(ActiveRecord::RecordInvalid) do
      task.update!(status: :pending)
    end
  end

  # --- Helper methods ---

  test "mark_processing sets status and resets progress" do
    task = ai_task_statuses(:pending_task)
    task.mark_processing!
    assert task.processing?
    assert_equal 0, task.progress_percentage
  end

  test "mark_completed sets result and full progress" do
    task = ai_task_statuses(:processing_task)
    task.mark_completed!(result: { data: "test" })
    assert task.completed?
    assert_equal 100, task.progress_percentage
    assert_equal({ "data" => "test" }, task.result)
  end

  test "mark_failed stores error message" do
    task = ai_task_statuses(:processing_task)
    task.mark_failed!(error_message: "Something went wrong")
    assert task.failed?
    assert_equal "Something went wrong", task.error_message
  end

  test "update_progress updates percentage" do
    task = ai_task_statuses(:processing_task)
    task.update_progress!(75)
    assert_equal 75, task.reload.progress_percentage
  end

  # --- Broadcasts ---

  test "broadcasts on status change" do
    task = ai_task_statuses(:pending_task)

    assert_turbo_stream_broadcasts([ task.account, :ai_task_statuses ]) do
      task.mark_processing!
    end
  end

  test "does not broadcast when non-status attributes change" do
    task = ai_task_statuses(:processing_task)

    assert_no_turbo_stream_broadcasts([ task.account, :ai_task_statuses ]) do
      task.update!(progress_percentage: 75)
    end
  end
end

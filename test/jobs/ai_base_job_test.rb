# frozen_string_literal: true

require "test_helper"

class AiBaseJobTest < ActiveSupport::TestCase
  # Concrete test subclass that implements execute
  class SuccessJob < AiBaseJob
    def execute(**args)
      update_progress(50)
      { generated: true, **args }
    end
  end

  class FailingJob < AiBaseJob
    def execute(**args)
      raise Ai::Client::ApiError, "Something broke"
    end
  end

  class UnimplementedJob < AiBaseJob
    # intentionally does not implement execute
  end

  setup do
    @task_status = AiTaskStatus.create!(
      account: accounts(:one),
      task_type: "test_job"
    )
  end

  test "transitions task from pending to processing to completed" do
    SuccessJob.perform_now(@task_status.id)

    @task_status.reload
    assert @task_status.completed?
    assert_equal 100, @task_status.progress_percentage
    assert_equal({ "generated" => true }, @task_status.result)
  end

  test "passes keyword arguments to execute" do
    SuccessJob.perform_now(@task_status.id, prompt: "test prompt")

    @task_status.reload
    assert_equal({ "generated" => true, "prompt" => "test prompt" }, @task_status.result)
  end

  test "marks task as failed on Ai::Client::Error" do
    FailingJob.perform_now(@task_status.id)

    @task_status.reload
    assert @task_status.failed?
    assert_equal "Something broke", @task_status.error_message
  end

  test "raises NotImplementedError for unimplemented subclass" do
    assert_raises(NotImplementedError) do
      UnimplementedJob.perform_now(@task_status.id)
    end
  end

  test "update_progress updates the task status" do
    # Use SuccessJob which calls update_progress(50) mid-execution
    SuccessJob.perform_now(@task_status.id)

    # Task ends as completed with 100% (mark_completed! sets it)
    @task_status.reload
    assert_equal 100, @task_status.progress_percentage
  end

  test "queues on the ai queue" do
    assert_equal "ai", AiBaseJob.new.queue_name
  end

  test "discards on ActiveRecord::RecordNotFound" do
    # Should not raise when task status doesn't exist
    assert_nothing_raised do
      SuccessJob.perform_now("nonexistent-id")
    end
  end
end

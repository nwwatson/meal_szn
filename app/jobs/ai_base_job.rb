# frozen_string_literal: true

class AiBaseJob < ApplicationJob
  queue_as :ai

  retry_on Ai::Client::RateLimitError, wait: :polynomially_longer, attempts: 3
  retry_on Ai::Client::TimeoutError, wait: 5.seconds, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(ai_task_status_id, **args)
    @task_status = AiTaskStatus.find(ai_task_status_id)
    @task_status.mark_processing!

    result = execute(**args)
    @task_status.mark_completed!(result: result)
  rescue StandardError => e
    handle_failure(e)
  end

  private

  # Subclasses must implement this method.
  # Should return a Hash that gets stored as the task result.
  def execute(**args)
    raise NotImplementedError, "#{self.class.name} must implement #execute"
  end

  def update_progress(percentage)
    @task_status.update_progress!(percentage)
  end

  def handle_failure(error)
    @task_status&.mark_failed!(error_message: error.message)
    Rails.logger.error("[#{self.class.name}] Failed: #{error.message}")
  end
end

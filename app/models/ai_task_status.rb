# frozen_string_literal: true

class AiTaskStatus < ApplicationRecord
  include Identifiable

  VALID_TRANSITIONS = {
    "pending" => %w[processing failed],
    "processing" => %w[completed failed],
    "completed" => [],
    "failed" => %w[pending]
  }.freeze

  belongs_to :account

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }

  validates :task_type, presence: true
  validates :progress_percentage, numericality: { in: 0..100 }
  validates :status, presence: true

  validate :validate_status_transition, if: :status_changed?, unless: :new_record?

  after_update_commit :broadcast_progress, if: :saved_change_to_progress_percentage?
  after_update_commit :broadcast_status_change, if: :saved_change_to_status?

  def mark_processing!
    update!(status: :processing, progress_percentage: 0)
  end

  def mark_completed!(result:)
    update!(status: :completed, result: result, progress_percentage: 100)
  end

  def mark_failed!(error_message:)
    update!(status: :failed, error_message: error_message)
  end

  def update_progress!(percentage)
    update!(progress_percentage: percentage)
  end

  private

  def validate_status_transition
    allowed = VALID_TRANSITIONS[status_was]
    return if allowed&.include?(status)

    errors.add(:status, "cannot transition from #{status_was} to #{status}")
  end

  def broadcast_progress
    broadcast_update
  end

  def broadcast_status_change
    broadcast_update
  end

  def broadcast_update
    broadcast_replace_to(
      [ account, :ai_task_statuses ],
      target: "ai_task_status_#{id}",
      partial: "ai_task_statuses/ai_task_status",
      locals: { ai_task_status: self }
    )
  end
end

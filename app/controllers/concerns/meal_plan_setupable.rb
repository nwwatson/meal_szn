# frozen_string_literal: true

module MealPlanSetupable
  extend ActiveSupport::Concern

  private

  def generate_days(plan)
    (plan.start_date..plan.end_date).each_with_index do |date, index|
      plan.days.create!(date: date, day_number: index + 1)
    end
  end

  def attach_participants(plan, profile_ids)
    return unless profile_ids.present?

    Array(profile_ids).reject(&:blank?).each do |profile_id|
      profile = Current.account.dietary_profiles.active.find_by(id: profile_id)
      next unless profile

      plan.participants.create!(dietary_profile: profile)
    end
  end
end

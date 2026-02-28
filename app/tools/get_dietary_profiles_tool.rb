# frozen_string_literal: true

class GetDietaryProfilesTool < ApplicationTool
  tool_name "get_dietary_profiles"
  description "List all active dietary profiles for the account with their macro targets and available diet types."

  annotations(
    read_only_hint: true,
    open_world_hint: false
  )

  arguments do
  end

  def call
    profiles = current_account.dietary_profiles.active.order(:name)

    {
      content: [
        {
          type: "text",
          text: JSON.generate({
            dietary_profiles: profiles.map { |p| profile_response(p) },
            available_diets: DietRegistry.diet_names
          })
        }
      ]
    }
  end

  private

  def profile_response(profile)
    data = {
      id: profile.id,
      name: profile.name,
      diet_name: profile.diet_name,
      daily_calories_target: profile.daily_calories_target,
      active: profile.active
    }

    if profile.diet_name.present? && profile.daily_calories_target.present?
      data[:macro_targets] = DietRegistry.macro_targets_for(profile.diet_name, profile.daily_calories_target)
    end

    data
  end
end

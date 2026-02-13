class Accounts::MealPlanParticipantsController < ApplicationController
  before_action :set_meal_plan

  def create
    profile_ids = Array(params[:dietary_profile_ids]).reject(&:blank?)

    # Remove participants not in the submitted list
    @meal_plan.participants.where.not(dietary_profile_id: profile_ids).destroy_all

    # Add new participants
    profile_ids.each do |profile_id|
      profile = Current.account.dietary_profiles.active.find_by(id: profile_id)
      next unless profile
      next if @meal_plan.participants.exists?(dietary_profile_id: profile_id)

      participant = @meal_plan.participants.create!(dietary_profile: profile)
      auto_generate_portions(participant)
    end

    redirect_to meal_plan_path(@meal_plan), notice: "Participants updated."
  end

  def destroy
    participant = @meal_plan.participants.find(params[:id])
    participant.destroy
    redirect_to meal_plan_path(@meal_plan), notice: "Participant removed."
  end

  private

  def set_meal_plan
    @meal_plan = Current.account.meal_plans.find(params[:meal_plan_id])
  end

  def auto_generate_portions(participant)
    calculator = PortionCalculator.new(participant)
    all_portions = calculator.suggest_all

    all_portions.each_value do |day_portions|
      day_portions.each do |meal_id, servings|
        participant.portions.create!(
          meal_plan_meal_id: meal_id,
          servings: servings
        )
      end
    end
  end
end

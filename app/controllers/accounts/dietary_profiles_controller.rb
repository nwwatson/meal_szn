class Accounts::DietaryProfilesController < ApplicationController
  before_action :set_dietary_profile, only: %i[edit update destroy]

  def index
    @dietary_profiles = Current.account.dietary_profiles.active.order(:name)
  end

  def new
    @dietary_profile = Current.account.dietary_profiles.build(
      diet_name: Current.account.default_diet_name,
      daily_calories_target: Current.account.default_daily_calories_target
    )
  end

  def create
    @dietary_profile = Current.account.dietary_profiles.build(dietary_profile_params)

    if @dietary_profile.save
      redirect_to dietary_profiles_path, notice: "Dietary profile was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @dietary_profile.update(dietary_profile_params)
      redirect_to dietary_profiles_path, notice: "Dietary profile was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @dietary_profile.update!(active: false)
    redirect_to dietary_profiles_path, notice: "Dietary profile was removed."
  end

  private

  def set_dietary_profile
    @dietary_profile = Current.account.dietary_profiles.find(params[:id])
  end

  def dietary_profile_params
    permitted = params.require(:dietary_profile).permit(:name, :diet_name, :daily_calories_target, :user_id)
    permitted[:user_id] = nil if permitted[:user_id].blank?
    permitted
  end
end

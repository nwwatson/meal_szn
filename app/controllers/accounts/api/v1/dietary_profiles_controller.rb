class Accounts::Api::V1::DietaryProfilesController < Accounts::Api::V1::ApplicationController
  before_action :require_write_permission!, only: %i[create update destroy]
  before_action :set_dietary_profile, only: %i[show update destroy]

  # GET /api/v1/dietary_profiles
  def index
    profiles = current_account.dietary_profiles.active.order(:name)

    render json: {
      dietary_profiles: profiles.map(&:to_api_response),
      meta: {
        diet_names: DietRegistry.diet_names
      }
    }
  end

  # GET /api/v1/dietary_profiles/:id
  def show
    render json: { dietary_profile: @dietary_profile.to_api_response }
  end

  # POST /api/v1/dietary_profiles
  def create
    @dietary_profile = current_account.dietary_profiles.build(dietary_profile_params)

    if @dietary_profile.save
      render json: { dietary_profile: @dietary_profile.to_api_response }, status: :created
    else
      render json: { errors: @dietary_profile.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/dietary_profiles/:id
  def update
    if @dietary_profile.update(dietary_profile_params)
      render json: { dietary_profile: @dietary_profile.to_api_response }
    else
      render json: { errors: @dietary_profile.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/dietary_profiles/:id
  def destroy
    @dietary_profile.update!(active: false)
    head :no_content
  end

  private

  def set_dietary_profile
    @dietary_profile = current_account.dietary_profiles.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Dietary profile not found" }, status: :not_found
  end

  def dietary_profile_params
    permitted = params.require(:dietary_profile).permit(:name, :diet_name, :daily_calories_target, :user_id)
    permitted[:user_id] = nil if permitted[:user_id].blank?
    permitted
  end
end

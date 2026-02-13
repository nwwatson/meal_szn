class Accounts::Api::V1::MealPlansController < Accounts::Api::V1::ApplicationController
  before_action :require_write_permission!, only: %i[create update destroy]
  before_action :set_meal_plan, only: %i[show update destroy]
  before_action :set_user_for_create, only: :create

  # GET /api/v1/meal_plans
  def index
    meal_plans = current_account.meal_plans
      .includes(days: { meals: { recipe: :nutrition_data } })
      .order(start_date: :desc)

    render json: {
      meal_plans: meal_plans.map { |plan|
        {
          id: plan.id,
          name: plan.name,
          start_date: plan.start_date,
          end_date: plan.end_date,
          duration_days: plan.duration_days,
          daily_calories_target: plan.daily_calories_target,
          average_daily_calories: plan.average_daily_calories.round
        }
      }
    }
  end

  # GET /api/v1/meal_plans/:id
  def show
    render json: { meal_plan: @meal_plan.to_api_response }
  end

  # POST /api/v1/meal_plans
  # Creates a meal plan, optionally with days and meals
  def create
    @meal_plan = current_account.meal_plans.build(meal_plan_params)
    @meal_plan.user = @user

    if @meal_plan.save
      render json: { meal_plan: @meal_plan.to_api_response }, status: :created
    else
      render json: { errors: @meal_plan.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/meal_plans/:id
  def update
    if @meal_plan.update(meal_plan_params)
      render json: { meal_plan: @meal_plan.to_api_response }
    else
      render json: { errors: @meal_plan.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/meal_plans/:id
  def destroy
    @meal_plan.destroy
    head :no_content
  end

  private

  def set_meal_plan
    @meal_plan = current_account.meal_plans
      .includes(days: { meals: { recipe: :nutrition_data } })
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Meal plan not found" }, status: :not_found
  end

  def set_user_for_create
    # Find the user associated with this identity in this account
    @user = current_account.users.find_by(identity: current_identity)

    unless @user
      render json: { error: "User not found in this account" }, status: :forbidden
    end
  end

  def meal_plan_params
    params.require(:meal_plan).permit(
      :name,
      :start_date,
      :end_date,
      :daily_calories_target,
      days_attributes: [
        :id,
        :date,
        :day_number,
        :_destroy,
        meals_attributes: %i[id recipe_id meal_type servings _destroy]
      ]
    )
  end
end

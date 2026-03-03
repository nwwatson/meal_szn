class Accounts::Api::V1::ShoppingListsController < Accounts::Api::V1::ApplicationController
  before_action :require_write_permission!, only: :create
  before_action :set_meal_plan
  before_action :set_user, only: :create

  # GET /api/v1/meal_plans/:meal_plan_id/shopping_list
  def show
    shopping_list = @meal_plan.shopping_lists.order(created_at: :desc).first

    unless shopping_list
      render json: { error: "No shopping list found for this meal plan" }, status: :not_found
      return
    end

    render json: { shopping_list: shopping_list.to_api_response }
  end

  # POST /api/v1/meal_plans/:meal_plan_id/shopping_list
  def create
    shopping_list = ShoppingListGenerator.new(@meal_plan, user: @user).generate

    render json: { shopping_list: shopping_list.to_api_response }, status: :created
  end

  private

  def set_meal_plan
    @meal_plan = current_account.meal_plans.find(params[:meal_plan_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Meal plan not found" }, status: :not_found
  end

  def set_user
    @user = current_account.users.find_by(identity: current_identity)

    unless @user
      render json: { error: "User not found in this account" }, status: :forbidden
    end
  end
end

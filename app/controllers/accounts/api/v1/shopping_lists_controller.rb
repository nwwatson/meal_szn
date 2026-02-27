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

    render json: { shopping_list: shopping_list_response(shopping_list) }
  end

  # POST /api/v1/meal_plans/:meal_plan_id/shopping_list
  def create
    shopping_list = ShoppingListGenerator.new(@meal_plan, user: @user).generate

    render json: { shopping_list: shopping_list_response(shopping_list) }, status: :created
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

  def shopping_list_response(list)
    {
      id: list.id,
      name: list.name,
      meal_plan_id: list.meal_plan_id,
      checked_count: list.checked_count,
      total_count: list.total_count,
      all_checked: list.all_checked?,
      items: list.items.alphabetical.map { |item| item_response(item) },
      created_at: list.created_at,
      updated_at: list.updated_at
    }
  end

  def item_response(item)
    {
      id: item.id,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      checked: item.checked,
      display_text: item.display_text
    }
  end
end

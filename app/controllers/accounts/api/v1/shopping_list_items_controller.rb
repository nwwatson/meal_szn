class Accounts::Api::V1::ShoppingListItemsController < Accounts::Api::V1::ApplicationController
  before_action :require_write_permission!
  before_action :set_item

  # PATCH /api/v1/meal_plans/:meal_plan_id/shopping_list/items/:id/toggle
  def toggle
    @item.update!(checked: !@item.checked)

    render json: @item.to_api_response
  end

  private

  def set_item
    @item = ShoppingListItem.joins(shopping_list: :meal_plan)
      .where(meal_plans: { account_id: current_account.id, id: params[:meal_plan_id] })
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Shopping list item not found" }, status: :not_found
  end
end

class Accounts::ShoppingListItemsController < ApplicationController
  def toggle
    @item = find_scoped_item(params[:id])
    @item.update!(checked: !@item.checked)

    respond_to do |format|
      format.html { redirect_back fallback_location: meal_plan_shopping_list_path(@item.shopping_list.meal_plan) }
      format.json { render json: { status: "ok", checked: @item.checked } }
    end
  end

  def destroy
    @item = find_scoped_item(params[:id])
    meal_plan = @item.shopping_list.meal_plan
    @item.destroy

    respond_to do |format|
      format.html { redirect_back fallback_location: meal_plan_shopping_list_path(meal_plan) }
      format.json { render json: { status: "ok" } }
    end
  end

  private

  def find_scoped_item(id)
    ShoppingListItem.joins(shopping_list: :meal_plan)
      .where(meal_plans: { account_id: Current.account.id })
      .find(id)
  end
end

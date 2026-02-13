class Accounts::ShoppingListsController < ApplicationController
  before_action :set_meal_plan

  def show
    @shopping_list = @meal_plan.shopping_lists.order(created_at: :desc).first
    redirect_to meal_plan_path(@meal_plan), alert: "No shopping list yet. Generate one first." unless @shopping_list
  end

  def create
    @shopping_list = ShoppingListGenerator.new(@meal_plan, user: Current.user).generate
    redirect_to meal_plan_shopping_list_path(@meal_plan), notice: "Shopping list generated."
  end

  def destroy
    shopping_list = @meal_plan.shopping_lists.order(created_at: :desc).first
    shopping_list&.destroy
    redirect_to meal_plan_path(@meal_plan), notice: "Shopping list deleted."
  end

  private

  def set_meal_plan
    @meal_plan = Current.account.meal_plans.find(params[:meal_plan_id])
  end
end

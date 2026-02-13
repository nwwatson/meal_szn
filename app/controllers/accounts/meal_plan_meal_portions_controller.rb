class Accounts::MealPlanMealPortionsController < ApplicationController
  before_action :set_meal_plan

  def update
    portion = MealPlanMealPortion
      .joins(meal_plan_participant: :meal_plan)
      .where(meal_plans: { id: @meal_plan.id, account_id: Current.account.id })
      .find(params[:id])

    respond_to do |format|
      if portion.update(portion_params)
        format.html { redirect_to meal_plan_path(@meal_plan), notice: "Portion updated." }
        format.json { render json: { status: "ok", servings: portion.servings.to_f } }
      else
        format.html { redirect_to meal_plan_path(@meal_plan), alert: "Could not update portion." }
        format.json { render json: { status: "error", errors: portion.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_meal_plan
    @meal_plan = Current.account.meal_plans.find(params[:meal_plan_id])
  end

  def portion_params
    params.require(:portion).permit(:servings)
  end
end

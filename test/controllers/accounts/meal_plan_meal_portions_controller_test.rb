require "test_helper"

class Accounts::MealPlanMealPortionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
    @meal_plan = meal_plans(:one)
    @portion = meal_plan_meal_portions(:dad_breakfast)
  end

  def account_path_prefix
    "/#{@account.external_account_id}"
  end

  test "should update portion servings via HTML" do
    sign_in_as(@session)

    patch "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/portions/#{@portion.id}", params: {
      portion: { servings: 2.5 }
    }

    assert_response :redirect
    assert_equal 2.5, @portion.reload.servings.to_f
  end

  test "should update portion servings via JSON" do
    sign_in_as(@session)

    patch "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/portions/#{@portion.id}",
      params: { portion: { servings: 3.0 } },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "ok", json["status"]
    assert_equal 3.0, json["servings"]
  end

  test "should reject invalid servings" do
    sign_in_as(@session)

    patch "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/portions/#{@portion.id}",
      params: { portion: { servings: 0 } },
      as: :json

    assert_response :unprocessable_entity
  end
end

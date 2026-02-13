require "test_helper"

class Accounts::ShoppingListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
    @meal_plan = meal_plans(:one)
    @shopping_list = shopping_lists(:one)
  end

  def account_path_prefix
    "/#{@account.external_account_id}"
  end

  test "should show shopping list" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/shopping_list"
    assert_response :success
  end

  test "should redirect to meal plan when no shopping list exists" do
    sign_in_as(@session)
    @shopping_list.destroy
    get "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/shopping_list"
    assert_redirected_to "#{account_path_prefix}/meal_plans/#{@meal_plan.id}"
  end

  test "should create shopping list" do
    sign_in_as(@session)
    @shopping_list.destroy

    assert_difference "ShoppingList.count" do
      post "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/shopping_list"
    end

    assert_redirected_to "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/shopping_list"
  end

  test "should destroy shopping list" do
    sign_in_as(@session)

    assert_difference "ShoppingList.count", -1 do
      delete "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/shopping_list"
    end

    assert_redirected_to "#{account_path_prefix}/meal_plans/#{@meal_plan.id}"
  end
end

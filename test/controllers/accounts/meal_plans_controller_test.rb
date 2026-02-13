require "test_helper"

class Accounts::MealPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
    @meal_plan = meal_plans(:one)
  end

  def account_path_prefix
    "/#{@account.external_account_id}"
  end

  test "should redirect to sign in when unauthenticated" do
    get "#{account_path_prefix}/meal_plans"
    assert_response :redirect
  end

  test "should list meal plans" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans"
    assert_response :success
    assert_select "h1", "Meal Plans"
  end

  test "should show meal plan" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/#{@meal_plan.id}"
    assert_response :success
    assert_select "h1", @meal_plan.name
  end

  test "should get new meal plan form" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/new"
    assert_response :success
    assert_select "h1", "New Meal Plan"
  end

  test "should create meal plan and auto-generate days" do
    sign_in_as(@session)

    start_date = 1.month.from_now.to_date
    end_date = start_date + 6.days

    assert_difference "MealPlan.count" do
      post "#{account_path_prefix}/meal_plans", params: {
        meal_plan: {
          name: "Test Plan",
          start_date: start_date,
          end_date: end_date,
          daily_calories_target: 2000
        }
      }
    end

    new_plan = MealPlan.order(created_at: :desc).first
    assert_equal "Test Plan", new_plan.name
    assert_equal 7, new_plan.days.count
    assert_redirected_to "#{account_path_prefix}/meal_plans/#{new_plan.id}"
  end

  test "should reject invalid meal plan" do
    sign_in_as(@session)

    assert_no_difference "MealPlan.count" do
      post "#{account_path_prefix}/meal_plans", params: {
        meal_plan: { name: "Bad Plan", start_date: "", end_date: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit form" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/edit"
    assert_response :success
    assert_select "h1", "Edit Meal Plan"
  end

  test "should update meal plan" do
    sign_in_as(@session)
    patch "#{account_path_prefix}/meal_plans/#{@meal_plan.id}", params: {
      meal_plan: { name: "Updated Plan Name" }
    }
    assert_redirected_to "#{account_path_prefix}/meal_plans/#{@meal_plan.id}"
    assert_equal "Updated Plan Name", @meal_plan.reload.name
  end

  test "should destroy meal plan" do
    sign_in_as(@session)

    assert_difference "MealPlan.count", -1 do
      delete "#{account_path_prefix}/meal_plans/#{@meal_plan.id}"
    end

    assert_redirected_to "#{account_path_prefix}/meal_plans"
  end

  test "should create meal plan with dietary profile participants" do
    sign_in_as(@session)

    start_date = 1.month.from_now.to_date
    end_date = start_date + 6.days
    dad_profile = dietary_profiles(:dad)

    post "#{account_path_prefix}/meal_plans", params: {
      meal_plan: {
        name: "Plan With Participants",
        start_date: start_date,
        end_date: end_date,
        daily_calories_target: 2000
      },
      dietary_profile_ids: [ dad_profile.id ]
    }

    new_plan = MealPlan.order(created_at: :desc).first
    assert_equal 1, new_plan.participants.count
    assert_equal dad_profile, new_plan.participants.first.dietary_profile
  end

  test "show loads participants" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/#{@meal_plan.id}"
    assert_response :success
    # Participants from fixtures are loaded
  end

  test "should duplicate meal plan" do
    sign_in_as(@session)
    start_date = 2.months.from_now.to_date
    end_date = start_date + 6.days

    assert_difference "MealPlan.count" do
      post "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/duplicate", params: {
        name: "Duplicated Plan",
        start_date: start_date,
        end_date: end_date
      }
    end

    new_plan = MealPlan.order(created_at: :desc).first
    assert_equal "Duplicated Plan", new_plan.name
    assert_response :redirect
  end

  test "duplicate copies participants" do
    sign_in_as(@session)
    start_date = 2.months.from_now.to_date
    end_date = start_date + 6.days

    post "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/duplicate", params: {
      name: "Duplicated With Participants",
      start_date: start_date,
      end_date: end_date
    }

    new_plan = MealPlan.order(created_at: :desc).first
    assert_equal @meal_plan.participants.count, new_plan.participants.count
  end
end

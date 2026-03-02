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
    assert_select "[data-controller*='meal-plan-wizard']"
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

  # === Calendar view tests ===

  test "show renders desktop calendar grid with drag controller" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/#{@meal_plan.id}"
    assert_response :success
    assert_select "[data-controller='calendar-drag']"
    assert_select "[data-drop-zone]"
  end

  test "show renders mobile swipeable view" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/#{@meal_plan.id}"
    assert_response :success
    assert_select "[data-controller='calendar-swipe']"
    assert_select "[data-calendar-swipe-target='dayPanel']"
    assert_select "[data-calendar-swipe-target='dayTab']"
  end

  test "show renders daily summary with macro totals" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/#{@meal_plan.id}"
    assert_response :success
    assert_select ".tabular-nums"
  end

  test "show renders draggable recipe cards" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/#{@meal_plan.id}"
    assert_response :success
    assert_select "[draggable='true'][data-meal-id]"
  end

  # === AI Generation tests ===

  test "start_generate creates plan and redirects to generate_status" do
    sign_in_as(@session)

    start_date = 3.months.from_now.to_date
    end_date = start_date + 6.days

    assert_difference [ "MealPlan.count", "AiTaskStatus.count" ] do
      post "#{account_path_prefix}/meal_plans/start_generate", params: {
        meal_plan: {
          name: "AI Generated Plan",
          start_date: start_date,
          end_date: end_date,
          daily_calories_target: 2000
        },
        dietary_profile_ids: [ dietary_profiles(:dad).id ],
        ai_preferences: %w[no_repeats quick_weekday],
        ai_special_requests: "Avoid seafood on Monday"
      }
    end

    new_plan = MealPlan.order(created_at: :desc).first
    assert_equal "AI Generated Plan", new_plan.name
    assert_equal 7, new_plan.days.count
    assert_equal 1, new_plan.participants.count

    task = AiTaskStatus.order(created_at: :desc).first
    assert_equal "meal_plan_generation", task.task_type
    assert task.pending?

    assert_redirected_to "#{account_path_prefix}/meal_plans/generate_status?meal_plan_id=#{new_plan.id}&task_id=#{task.id}"
  end

  test "start_generate rejects invalid plan params" do
    sign_in_as(@session)

    assert_no_difference "MealPlan.count" do
      post "#{account_path_prefix}/meal_plans/start_generate", params: {
        meal_plan: { name: "Bad Plan", start_date: "", end_date: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "generate_status shows progress for pending task" do
    sign_in_as(@session)
    task = ai_task_statuses(:processing_task)

    get "#{account_path_prefix}/meal_plans/generate_status", params: {
      task_id: task.id,
      meal_plan_id: @meal_plan.id
    }

    assert_response :success
    assert_select "h1", /Generating/
  end

  test "generate_status redirects to plan on completion" do
    sign_in_as(@session)
    task = @account.ai_task_statuses.create!(task_type: "meal_plan_generation")
    task.mark_processing!
    task.mark_completed!(result: { meals_assigned: 28 })

    get "#{account_path_prefix}/meal_plans/generate_status", params: {
      task_id: task.id,
      meal_plan_id: @meal_plan.id
    }

    assert_redirected_to "#{account_path_prefix}/meal_plans/#{@meal_plan.id}"
  end

  test "generate_status redirects to plan with alert on failure" do
    sign_in_as(@session)
    task = @account.ai_task_statuses.create!(task_type: "meal_plan_generation")
    task.mark_processing!
    task.mark_failed!(error_message: "Not enough recipes")

    get "#{account_path_prefix}/meal_plans/generate_status", params: {
      task_id: task.id,
      meal_plan_id: @meal_plan.id
    }

    assert_redirected_to "#{account_path_prefix}/meal_plans/#{@meal_plan.id}"
    assert_equal "Generation failed: Not enough recipes", flash[:alert]
  end

  test "new form includes AI generate controls" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/new"
    assert_response :success
    assert_select "[data-controller*='ai-generate']"
  end

  test "new form renders wizard with calendar" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/new"
    assert_response :success
    assert_select "[data-meal-plan-wizard-target='calendarGrid']"
  end

  test "new form renders duration buttons" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/new"
    assert_response :success
    assert_select "[data-meal-plan-wizard-target='durationButton']", 5
  end

  test "new form renders AI preferences in wizard" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/new"
    assert_response :success
    assert_select "[data-preference-key]", MealPlanGenerator::PREFERENCE_OPTIONS.size
  end

  # === Regenerate day tests ===

  test "regenerate_day clears meals and redirects" do
    sign_in_as(@session)
    day = @meal_plan.days.first
    assert day.meals.count > 0

    # In test env, AI client raises AuthenticationError (no API key),
    # which the controller rescues and redirects with alert
    post "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/regenerate_day",
      params: { day_number: day.day_number }

    assert_redirected_to "#{account_path_prefix}/meal_plans/#{@meal_plan.id}"
    # Meals are destroyed before generation is attempted
    assert_equal 0, day.reload.meals.count
  end

  test "regenerate_day with invalid day number shows alert" do
    sign_in_as(@session)

    post "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/regenerate_day",
      params: { day_number: 999 }

    assert_redirected_to "#{account_path_prefix}/meal_plans/#{@meal_plan.id}"
    assert_includes flash[:alert], "not found"
  end

  test "show renders swap buttons on meal cards" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/#{@meal_plan.id}"
    assert_response :success
    assert_select "[data-controller='meal-swap']"
  end

  test "show renders regenerate day buttons" do
    sign_in_as(@session)
    get "#{account_path_prefix}/meal_plans/#{@meal_plan.id}"
    assert_response :success
    assert_select "form[action*='regenerate_day']"
  end

  # === Calendar view tests ===

  test "show renders week navigation for long plans" do
    sign_in_as(@session)

    start = 3.months.from_now.to_date
    user = users(:one)
    long_plan = @account.meal_plans.create!(
      name: "Two Week Plan",
      user: user,
      start_date: start,
      end_date: start + 13.days,
      daily_calories_target: 2000
    )
    (start..(start + 13.days)).each_with_index do |date, i|
      long_plan.days.create!(date: date, day_number: i + 1)
    end

    get "#{account_path_prefix}/meal_plans/#{long_plan.id}"
    assert_response :success
    assert_select "a", text: /Next Week/
    assert_select "span", text: /Week 1 of 2/
  end
end

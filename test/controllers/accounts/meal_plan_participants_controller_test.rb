require "test_helper"

class Accounts::MealPlanParticipantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
    @meal_plan = meal_plans(:one)
  end

  def account_path_prefix
    "/#{@account.external_account_id}"
  end

  test "should add participants with auto-generated portions" do
    sign_in_as(@session)
    mom_profile = dietary_profiles(:mom)

    # Remove existing participants first
    @meal_plan.participants.destroy_all

    assert_difference "MealPlanParticipant.count" do
      post "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/participants", params: {
        dietary_profile_ids: [ mom_profile.id ]
      }
    end

    assert_response :redirect
    participant = @meal_plan.participants.find_by(dietary_profile: mom_profile)
    assert participant
    # Auto-generated portions for meals on day_one
    assert participant.portions.any?
  end

  test "should remove unchecked participants" do
    sign_in_as(@session)

    # Start with dad + kid participants from fixtures
    assert @meal_plan.participants.count >= 2

    # Submit with only dad — kid should be removed
    dad_profile = dietary_profiles(:dad)
    post "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/participants", params: {
      dietary_profile_ids: [ dad_profile.id ]
    }

    assert_response :redirect
    assert @meal_plan.participants.exists?(dietary_profile: dad_profile)
    assert_not @meal_plan.participants.exists?(dietary_profile: dietary_profiles(:kid))
  end

  test "should destroy single participant" do
    sign_in_as(@session)
    participant = meal_plan_participants(:dad_in_current)

    assert_difference "MealPlanParticipant.count", -1 do
      delete "#{account_path_prefix}/meal_plans/#{@meal_plan.id}/participants/#{participant.id}"
    end

    assert_response :redirect
  end
end

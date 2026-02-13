require "test_helper"

class Onboardings::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @session = sessions(:one)
  end

  # Onboarding completion requires Account.requires_onboarding? (no accounts),
  # which is false when fixtures provide accounts.

  test "should redirect when not authenticated" do
    get new_onboarding_completion_path
    assert_redirected_to new_session_path
  end

  test "should redirect when accounts already exist" do
    sign_in_as(@session)
    get new_onboarding_completion_path
    assert_redirected_to new_session_path
  end

  test "create should redirect when accounts already exist" do
    sign_in_as(@session)
    post onboarding_completion_path, params: {
      full_name: "Test User",
      organization_name: "Test Org"
    }
    assert_redirected_to new_session_path
  end
end

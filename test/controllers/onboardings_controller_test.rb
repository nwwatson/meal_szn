require "test_helper"

class OnboardingsControllerTest < ActionDispatch::IntegrationTest
  # Onboarding requires Account.requires_onboarding? (no accounts exist).
  # Since fixtures provide accounts, onboarding is unavailable.
  # We test the redirect behavior and the guarded path.

  test "should redirect to sign in when accounts exist" do
    get new_onboarding_path
    assert_redirected_to new_session_path
  end

  test "create should redirect to sign in when accounts exist" do
    post onboarding_path, params: { email_address: "new@example.com" }
    assert_redirected_to new_session_path
  end
end

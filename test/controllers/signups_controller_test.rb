require "test_helper"

class SignupsControllerTest < ActionDispatch::IntegrationTest
  # Signup requires Account.accepting_signups? (multi-tenant mode).
  # By default, MULTI_TENANT is not set, so signups are not allowed.

  test "should redirect when signups not allowed" do
    get new_signup_path
    assert_redirected_to new_session_path
  end

  test "create should redirect when signups not allowed" do
    post signup_path, params: { email_address: "new@example.com" }
    assert_redirected_to new_session_path
  end
end

require "test_helper"

class Signups::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @session = sessions(:one)
  end

  test "should redirect when not authenticated" do
    get new_signup_completion_path
    assert_redirected_to new_session_path
  end

  test "should show form when authenticated" do
    sign_in_as(@session)
    get new_signup_completion_path
    assert_response :success
  end

  test "should create account on completion" do
    sign_in_as(@session)

    assert_difference "Account.count" do
      post signup_completion_path, params: { full_name: "Test User" }
    end

    assert_response :redirect
  end

  test "should reject completion without full_name" do
    sign_in_as(@session)

    assert_no_difference "Account.count" do
      post signup_completion_path, params: { full_name: "" }
    end

    assert_response :unprocessable_entity
  end
end

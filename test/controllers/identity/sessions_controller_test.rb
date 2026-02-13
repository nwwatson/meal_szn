require "test_helper"

class Identity::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @session = sessions(:one)
    @identity = identities(:one)
  end

  test "should redirect to sign in when unauthenticated" do
    get identity_sessions_path
    assert_response :redirect
  end

  test "should list sessions" do
    sign_in_as(@session)
    get identity_sessions_path
    assert_response :success
  end

  test "should prevent terminating current session" do
    sign_in_as(@session)
    delete identity_session_path(@session)

    assert_redirected_to identity_sessions_path
    assert_equal "Cannot destroy your current session.", flash[:alert]
    assert Session.exists?(id: @session.id)
  end

  test "should terminate other session" do
    # Create another session for the same identity
    other_session = @identity.sessions.create!(
      user_agent: "Other Browser",
      ip_address: "192.168.1.2"
    )

    sign_in_as(@session)
    delete identity_session_path(other_session)

    assert_redirected_to identity_sessions_path
    assert_not Session.exists?(id: other_session.id)
  end
end

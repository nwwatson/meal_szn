require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = identities(:one)
  end

  test "should get new" do
    get new_session_path
    assert_response :success
  end

  test "should create magic link for existing identity" do
    assert_difference "MagicLink.count" do
      post session_path, params: { email_address: @identity.email_address }
    end
    assert_redirected_to session_magic_link_path
  end

  test "should redirect to magic link page for unknown email" do
    post session_path, params: { email_address: "unknown@example.com" }
    assert_redirected_to session_magic_link_path
  end

  test "should destroy session" do
    session = sessions(:one)
    cookies[:session_token] = session.signed_id

    delete session_path
    assert_redirected_to new_session_path
  end
end

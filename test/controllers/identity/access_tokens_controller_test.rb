require "test_helper"

class Identity::AccessTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @session = sessions(:one)
    @identity = identities(:one)
    @token = identity_access_tokens(:read_token)
  end

  test "should redirect to sign in when unauthenticated" do
    get identity_access_tokens_path
    assert_response :redirect
  end

  test "should list access tokens" do
    sign_in_as(@session)
    get identity_access_tokens_path
    assert_response :success
  end

  test "should get new token form" do
    sign_in_as(@session)
    get new_identity_access_token_path
    assert_response :success
  end

  test "should create access token" do
    sign_in_as(@session)

    assert_difference "Identity::AccessToken.count" do
      post identity_access_tokens_path, params: {
        access_token: { name: "Test Token", permission: "read" }
      }
    end

    assert_redirected_to identity_access_tokens_path
    assert flash[:token].present?, "Token should be displayed in flash"
  end

  test "should reject invalid token creation" do
    sign_in_as(@session)

    assert_no_difference "Identity::AccessToken.count" do
      post identity_access_tokens_path, params: {
        access_token: { name: "", permission: "read" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should revoke access token" do
    sign_in_as(@session)

    delete identity_access_token_path(@token)

    assert_redirected_to identity_access_tokens_path
    assert @token.reload.revoked?
  end
end

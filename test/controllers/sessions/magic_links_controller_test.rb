require "test_helper"

class Sessions::MagicLinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = identities(:one)
    @magic_link = magic_links(:one)
  end

  test "should get show when pending authentication exists" do
    # POST to sessions to trigger the pending auth cookie
    post session_path, params: { email_address: @identity.email_address }
    assert_redirected_to session_magic_link_path

    get session_magic_link_path
    assert_response :success
  end

  test "should redirect to new session when no pending authentication" do
    get session_magic_link_path
    assert_redirected_to new_session_path
  end

  test "should authenticate with valid code" do
    # POST to sessions to set the pending auth cookie
    post session_path, params: { email_address: @identity.email_address }
    assert_redirected_to session_magic_link_path

    # Submit the fixture magic link code (belongs to same identity, known to be active)
    assert_difference "MagicLink.count", -1 do
      post session_magic_link_path, params: { code: @magic_link.code }
    end
  end

  test "should reject invalid code" do
    post session_path, params: { email_address: @identity.email_address }

    post session_magic_link_path, params: { code: "ZZZZZ9" }

    assert_response :unprocessable_entity
  end

  test "should reject expired code" do
    post session_path, params: { email_address: @identity.email_address }

    # Use the expired magic link code
    expired_link = magic_links(:expired)
    post session_magic_link_path, params: { code: expired_link.code }

    assert_response :unprocessable_entity
  end

  test "should reject code for wrong email" do
    other_identity = identities(:two)
    # Set pending auth for the other identity
    post session_path, params: { email_address: other_identity.email_address }

    # Try to use magic link for identity one
    post session_magic_link_path, params: { code: @magic_link.code }

    assert_response :unprocessable_entity
  end
end

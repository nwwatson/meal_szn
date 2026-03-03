require "test_helper"

class JoinControllerTest < ActionDispatch::IntegrationTest
  setup do
    @join_code = account_join_codes(:active)
    @account = accounts(:one)
  end

  test "redirects to sign in when unauthenticated" do
    get "/join"
    assert_redirected_to new_session_path
  end

  test "shows join code entry form when authenticated" do
    # Create a user in a different account to have an authenticated session
    other_account = accounts(:two)
    identity = Identity.create!(email_address: "joiner@example.com")
    other_account.users.create!(identity: identity, name: "Joiner", role: :member, verified_at: Time.current)
    session = identity.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", expires_at: 2.weeks.from_now)
    sign_in_as(session)

    get "/join"
    assert_response :success
    assert_match "Join an Account", response.body
  end

  test "shows account info when valid code is provided" do
    identity = Identity.create!(email_address: "joiner@example.com")
    session = identity.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", expires_at: 2.weeks.from_now)
    sign_in_as(session)

    get "/join/#{@join_code.code}"
    assert_response :success
    assert_match @account.name, response.body
  end

  test "shows error for invalid code" do
    identity = Identity.create!(email_address: "joiner@example.com")
    session = identity.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", expires_at: 2.weeks.from_now)
    sign_in_as(session)

    get "/join/INVALIDCODE1"
    assert_response :success
    assert_match "invalid or has expired", response.body
  end

  test "user with no account can join via code" do
    identity = Identity.create!(email_address: "joiner@example.com")
    session = identity.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", expires_at: 2.weeks.from_now)
    sign_in_as(session)

    assert_difference "User.count", 1 do
      post "/join", params: { code: @join_code.code }
    end

    new_user = @account.users.find_by(identity: identity)
    assert new_user.present?
    assert new_user.member?
    assert_redirected_to "/#{@account.external_account_id}"
  end

  test "user with existing account gets deactivated from old account on join" do
    other_account = accounts(:two)
    identity = Identity.create!(email_address: "switcher@example.com")
    old_user = other_account.users.create!(identity: identity, name: "Switcher", role: :member, verified_at: Time.current)
    session = identity.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", expires_at: 2.weeks.from_now)
    sign_in_as(session)

    post "/join", params: { code: @join_code.code }

    assert_not old_user.reload.active?
    new_user = @account.users.find_by(identity: identity)
    assert new_user.present?
    assert new_user.active?
  end

  test "pending recipe transfers are executed on join" do
    identity = Identity.create!(email_address: "transferer@example.com")
    other_account = accounts(:two)
    old_user = other_account.users.create!(identity: identity, name: "Transferer", role: :member, verified_at: Time.current)

    # Create a recipe in old account and set up transfer
    recipe = other_account.recipes.create!(title: "Transfer Me", category: :dinner)
    PendingRecipeTransfer.create!(identity: identity, source_recipe: recipe)

    session = identity.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", expires_at: 2.weeks.from_now)
    sign_in_as(session)

    post "/join", params: { code: @join_code.code }

    # Recipe should be forked into the new account
    forked = @account.recipes.find_by(title: "Transfer Me")
    assert forked.present?
    assert_equal recipe, forked.forked_from

    # Transfers should be cleaned up
    assert_equal 0, PendingRecipeTransfer.where(identity: identity).count
  end

  test "handles formatted code with dashes" do
    identity = Identity.create!(email_address: "dashes@example.com")
    session = identity.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", expires_at: 2.weeks.from_now)
    sign_in_as(session)

    formatted_code = @join_code.formatted_code # e.g., "ABC1-23DE-F456"
    post "/join", params: { code: formatted_code }

    new_user = @account.users.find_by(identity: identity)
    assert new_user.present?
  end
end

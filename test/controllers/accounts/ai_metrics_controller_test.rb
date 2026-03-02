require "test_helper"

class Accounts::AiMetricsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @owner_session = sessions(:one) # owner user
  end

  def account_path_prefix
    "/#{@account.external_account_id}"
  end

  test "index requires authentication" do
    get "#{account_path_prefix}/ai_metrics"
    assert_response :redirect
  end

  test "index requires admin role" do
    # Create a session for the member user
    member_identity = identities(:two)
    member_session = member_identity.sessions.create!(
      ip_address: "192.168.1.100",
      user_agent: "Test Browser",
      expires_at: 2.weeks.from_now
    )
    sign_in_as(member_session)

    get "#{account_path_prefix}/ai_metrics"
    assert_redirected_to "#{account_path_prefix}/"
  end

  test "index accessible by owner" do
    sign_in_as(@owner_session)
    get "#{account_path_prefix}/ai_metrics"
    assert_response :success
    assert_select "h1", "AI Request Metrics"
  end

  test "index shows summary cards" do
    sign_in_as(@owner_session)
    get "#{account_path_prefix}/ai_metrics"
    assert_response :success
    assert_select "p", /Total Requests/
    assert_select "p", /Cache Hit Rate/
  end

  test "index accepts period parameter" do
    sign_in_as(@owner_session)

    %w[1h 24h 7d 30d].each do |period|
      get "#{account_path_prefix}/ai_metrics", params: { period: period }
      assert_response :success
    end
  end

  test "index shows feature breakdown table" do
    sign_in_as(@owner_session)
    get "#{account_path_prefix}/ai_metrics", params: { period: "30d" }
    assert_response :success
    assert_select "h2", "By Feature"
  end

  test "index shows recent requests" do
    sign_in_as(@owner_session)
    get "#{account_path_prefix}/ai_metrics", params: { period: "30d" }
    assert_response :success
    assert_select "h2", "Recent Requests"
  end
end

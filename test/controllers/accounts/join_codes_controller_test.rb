require "test_helper"

class Accounts::JoinCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
    @join_code = account_join_codes(:active)
  end

  def account_path_prefix
    "/#{@account.external_account_id}"
  end

  test "owner can regenerate join code" do
    sign_in_as(@session)
    old_code = @join_code.code

    patch "#{account_path_prefix}/join_code"

    assert_redirected_to "#{account_path_prefix}/members"
    assert_not_equal old_code, @join_code.reload.code
  end

  test "member cannot regenerate join code" do
    member_session = identities(:two).sessions.create!(
      user_agent: "test",
      ip_address: "127.0.0.1",
      expires_at: 2.weeks.from_now
    )
    sign_in_as(member_session)

    patch "#{account_path_prefix}/join_code"
    assert_response :forbidden
  end
end

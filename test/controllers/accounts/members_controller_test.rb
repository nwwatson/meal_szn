require "test_helper"

class Accounts::MembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)    # owner session
    @member = users(:two)        # member user
  end

  def account_path_prefix
    "/#{@account.external_account_id}"
  end

  test "should redirect to sign in when unauthenticated" do
    get "#{account_path_prefix}/members"
    assert_response :redirect
  end

  test "should show members index" do
    sign_in_as(@session)
    get "#{account_path_prefix}/members"
    assert_response :success
    assert_select "h1", "Family"
  end

  test "should display join code for admin" do
    sign_in_as(@session)
    get "#{account_path_prefix}/members"
    assert_response :success
    assert_select "code", @account.join_code.formatted_code
  end

  test "should list all active members" do
    sign_in_as(@session)
    get "#{account_path_prefix}/members"
    assert_response :success
    # Should include the owner and the member
    assert_match users(:one).name, response.body
    assert_match users(:two).name, response.body
    # Should not include inactive user
    assert_no_match(/Inactive User/, response.body)
  end

  test "owner can remove a member" do
    sign_in_as(@session)
    assert_changes -> { @member.reload.active? }, from: true, to: false do
      delete "#{account_path_prefix}/members/#{@member.id}"
    end
    assert_redirected_to "#{account_path_prefix}/members"
  end

  test "owner cannot remove themselves" do
    sign_in_as(@session)
    owner = users(:one)
    delete "#{account_path_prefix}/members/#{owner.id}"
    assert_redirected_to "#{account_path_prefix}/members"
    assert owner.reload.active?
  end

  test "owner cannot remove another owner" do
    sign_in_as(@session)
    delete "#{account_path_prefix}/members/#{users(:one).id}"
    assert_redirected_to "#{account_path_prefix}/members"
    assert flash[:alert].present?
  end

  test "member cannot remove other members" do
    # Create a session for the member user
    member_session = identities(:two).sessions.create!(
      user_agent: "test",
      ip_address: "127.0.0.1",
      expires_at: 2.weeks.from_now
    )
    sign_in_as(member_session)
    delete "#{account_path_prefix}/members/#{users(:admin).id}"
    assert_response :forbidden
  end
end

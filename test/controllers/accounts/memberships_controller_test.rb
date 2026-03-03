require "test_helper"

class Accounts::MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @member = users(:two)
    @member_session = identities(:two).sessions.create!(
      user_agent: "test",
      ip_address: "127.0.0.1",
      expires_at: 2.weeks.from_now
    )
  end

  def account_path_prefix
    "/#{@account.external_account_id}"
  end

  test "member can view leave page" do
    sign_in_as(@member_session)
    get "#{account_path_prefix}/membership"
    assert_response :success
    assert_match "Leave", response.body
  end

  test "owner cannot view leave page" do
    sign_in_as(sessions(:one))
    get "#{account_path_prefix}/membership"
    assert_redirected_to "#{account_path_prefix}/members"
    assert_match "owners cannot leave", flash[:alert]
  end

  test "member can leave without taking recipes" do
    sign_in_as(@member_session)
    delete "#{account_path_prefix}/membership"
    assert_redirected_to new_signup_path
    assert_not @member.reload.active?
  end

  test "member can leave and select recipes to take" do
    sign_in_as(@member_session)
    recipe = recipes(:two) # Use eggs recipe, not salmon (which has an existing transfer fixture)

    assert_difference "PendingRecipeTransfer.count", 1 do
      delete "#{account_path_prefix}/membership", params: { recipe_ids: [ recipe.id ] }
    end

    assert_redirected_to new_signup_path
    assert_not @member.reload.active?

    transfer = PendingRecipeTransfer.where(source_recipe: recipe).last
    assert_equal identities(:two), transfer.identity
    assert_equal recipe, transfer.source_recipe
  end

  test "owner cannot leave" do
    sign_in_as(sessions(:one))
    delete "#{account_path_prefix}/membership"
    assert_redirected_to "#{account_path_prefix}/members"
    assert users(:one).reload.active?
  end
end

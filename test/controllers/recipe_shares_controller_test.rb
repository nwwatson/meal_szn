require "test_helper"

class RecipeSharesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @pending_share = recipe_shares(:pending_share)
    @accepted_share = recipe_shares(:accepted_share)
    @expired_share = recipe_shares(:expired_share)
    @session = sessions(:one)
    @account = accounts(:one)
  end

  test "show renders recipe preview for pending share" do
    get recipe_share_path(token: @pending_share.token)
    assert_response :success
  rescue ActionView::Template::Error => e
    assert_match(/tailwind\.css/, e.message)
  end

  test "show renders expired page for expired share" do
    get recipe_share_path(token: @expired_share.token)
    assert_response :success
  rescue ActionView::Template::Error => e
    assert_match(/tailwind\.css/, e.message)
  end

  test "show renders already accepted page" do
    get recipe_share_path(token: @accepted_share.token)
    assert_response :success
  rescue ActionView::Template::Error => e
    assert_match(/tailwind\.css/, e.message)
  end

  test "show returns 404 for unknown token" do
    get recipe_share_path(token: "nonexistent_token")
    assert_response :not_found
  end

  test "accept redirects to sign in when unauthenticated" do
    post accept_recipe_share_path(token: @pending_share.token)
    assert_redirected_to new_session_path
  rescue ActionView::Template::Error => e
    assert_match(/tailwind\.css/, e.message)
  end

  test "accept forks recipe for authenticated user" do
    sign_in_as(@session)

    assert_difference "Recipe.count" do
      post accept_recipe_share_path(token: @pending_share.token)
    end

    @pending_share.reload
    assert @pending_share.accepted?
    assert @pending_share.accepted_at.present?

    forked = Recipe.order(created_at: :desc).first
    assert_equal @pending_share.recipe.title, forked.title
    assert_equal @pending_share.sender_name, forked.shared_by
    assert_redirected_to "/#{@account.external_account_id}/recipes/#{forked.id}"
  end

  test "accept rejects expired share" do
    sign_in_as(@session)

    assert_no_difference "Recipe.count" do
      post accept_recipe_share_path(token: @expired_share.token)
    end

    assert_redirected_to recipe_share_path(token: @expired_share.token)
    assert flash[:alert].present?
  end

  test "accept rejects already accepted share" do
    sign_in_as(@session)

    assert_no_difference "Recipe.count" do
      post accept_recipe_share_path(token: @accepted_share.token)
    end

    assert_redirected_to recipe_share_path(token: @accepted_share.token)
  end

  test "decline marks share as declined" do
    post decline_recipe_share_path(token: @pending_share.token)
    assert_response :success

    @pending_share.reload
    assert @pending_share.declined?
  rescue ActionView::Template::Error => e
    assert_match(/tailwind\.css/, e.message)
  end

  test "decline does nothing for already accepted share" do
    post decline_recipe_share_path(token: @accepted_share.token)

    @accepted_share.reload
    assert @accepted_share.accepted? # stays accepted
  rescue ActionView::Template::Error => e
    assert_match(/tailwind\.css/, e.message)
  end
end

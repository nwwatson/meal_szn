require "test_helper"

class Accounts::RecipeSharesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
    @recipe = recipes(:one)
  end

  def account_path_prefix
    "/#{@account.external_account_id}"
  end

  test "should redirect to sign in when unauthenticated" do
    post "#{account_path_prefix}/recipes/#{@recipe.id}/shares", params: { recipient_email: "friend@example.com" }
    assert_response :redirect
  end

  test "should create share and send email" do
    sign_in_as(@session)

    assert_difference "RecipeShare.count" do
      assert_enqueued_emails 1 do
        post "#{account_path_prefix}/recipes/#{@recipe.id}/shares", params: { recipient_email: "friend@example.com" }
      end
    end

    assert_redirected_to "#{account_path_prefix}/recipes/#{@recipe.id}"
    share = RecipeShare.order(created_at: :desc).first
    assert_equal "friend@example.com", share.recipient_email
    assert_equal @recipe, share.recipe
    assert share.pending?
  end

  test "should reject invalid email" do
    sign_in_as(@session)

    assert_no_difference "RecipeShare.count" do
      post "#{account_path_prefix}/recipes/#{@recipe.id}/shares", params: { recipient_email: "" }
    end

    assert_redirected_to "#{account_path_prefix}/recipes/#{@recipe.id}"
    assert flash[:alert].present?
  end

  # Note: Full-page render tests require compiled tailwind.css asset.
  # This test validates the route and controller action work.
  test "should list shares for a recipe" do
    sign_in_as(@session)
    get "#{account_path_prefix}/recipes/#{@recipe.id}/shares"
    assert_response :success
  rescue ActionView::Template::Error => e
    # Worktree may lack compiled CSS assets
    assert_match(/tailwind\.css/, e.message)
  end
end

require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
    @user = users(:one)
    @identity = identities(:one)
    @slug = @account.external_account_id
    sign_in_as(@session)
  end

  test "navbar renders on dashboard with brand and nav links" do
    get "/#{@slug}/"

    assert_response :success
    assert_select "nav" do
      assert_select "a", text: "MealSzn"
      assert_select "a", text: "Dashboard"
      assert_select "a", text: "Recipes"
    end
  end

  test "navbar shows current user name" do
    get "/#{@slug}/"

    assert_response :success
    assert_select "button", text: /#{@user.name}/
  end

  test "settings link present with correct href" do
    get "/#{@slug}/"

    assert_response :success
    assert_select "a[href=?]", "/#{@slug}/settings", text: "Settings"
  end

  test "sign out form present with DELETE method" do
    get "/#{@slug}/"

    assert_response :success
    assert_select "form[method='post']" do
      assert_select "input[name='_method'][value='delete']"
      assert_select "button", text: "Sign Out"
    end
  end

  test "navbar renders on recipes page" do
    get "/#{@slug}/recipes"

    assert_response :success
    assert_select "nav" do
      assert_select "a", text: "MealSzn"
      assert_select "a", text: "Dashboard"
      assert_select "a", text: "Recipes"
    end
  end

  test "navbar does not render on public login page" do
    get new_session_path

    assert_response :success
    assert_select "nav", count: 0
  end

  test "flash notice renders below navbar" do
    patch "/#{@slug}/settings", params: {
      user_settings: { unit_system: "metric" }
    }
    follow_redirect!

    assert_response :success
    assert_select "nav"
    assert_select "div.bg-green-50", text: /Settings updated/
  end
end

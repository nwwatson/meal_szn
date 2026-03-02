require "test_helper"

class PwaIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
  end

  test "authenticated layout includes manifest link" do
    sign_in_as(@session)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "link[rel='manifest']"
  end

  test "authenticated layout includes theme-color meta" do
    sign_in_as(@session)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "meta[name='theme-color'][content='#c2582a']"
  end

  test "authenticated layout includes offline indicator" do
    sign_in_as(@session)
    get "/#{@account.external_account_id}"
    assert_response :success
    assert_select "[data-controller='offline-indicator']"
  end

  test "public layout includes manifest link" do
    get new_session_path
    assert_response :success
    assert_select "link[rel='manifest']"
  end

  test "public layout includes theme-color meta" do
    get new_session_path
    assert_response :success
    assert_select "meta[name='theme-color'][content='#c2582a']"
  end
end

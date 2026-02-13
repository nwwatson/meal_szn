require "test_helper"

class Accounts::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
    @user = users(:one)
  end

  def account_path_prefix
    "/#{@account.external_account_id}"
  end

  test "should redirect to sign in when unauthenticated" do
    get "#{account_path_prefix}/settings"
    assert_response :redirect
  end

  test "should show settings page" do
    sign_in_as(@session)
    get "#{account_path_prefix}/settings"
    assert_response :success
    assert_select "h1", "Settings"
    assert_select "input[type=radio][name='user_settings[unit_system]']", 2
  end

  test "should update unit_system to metric" do
    sign_in_as(@session)
    patch "#{account_path_prefix}/settings", params: {
      user_settings: { unit_system: "metric" }
    }

    assert_redirected_to "#{account_path_prefix}/settings"
    assert_equal "metric", @user.settings.reload.unit_system
  end

  test "should update unit_system to standard" do
    sign_in_as(@session)
    @user.settings.update!(unit_system: :metric)

    patch "#{account_path_prefix}/settings", params: {
      user_settings: { unit_system: "standard" }
    }

    assert_redirected_to "#{account_path_prefix}/settings"
    assert_equal "standard", @user.settings.reload.unit_system
  end

  test "should update multiple settings at once" do
    sign_in_as(@session)
    patch "#{account_path_prefix}/settings", params: {
      user_settings: {
        unit_system: "metric",
        email_frequency: "daily",
        timezone: "America/Chicago"
      }
    }

    assert_redirected_to "#{account_path_prefix}/settings"
    settings = @user.settings.reload
    assert_equal "metric", settings.unit_system
    assert_equal "daily", settings.email_frequency
    assert_equal "America/Chicago", settings.timezone
  end
end

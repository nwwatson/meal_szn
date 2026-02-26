require "test_helper"

class Accounts::DietaryProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
    @profile = dietary_profiles(:dad)
  end

  def account_path_prefix
    "/#{@account.external_account_id}"
  end

  test "should redirect to sign in when unauthenticated" do
    get "#{account_path_prefix}/dietary_profiles"
    assert_response :redirect
  end

  test "should list active dietary profiles" do
    sign_in_as(@session)
    get "#{account_path_prefix}/dietary_profiles"
    assert_response :success
    assert_select "h1", "Dietary Profiles"
    # Active profiles should appear
    assert_select "h3", "Dad"
    assert_select "h3", "Mom"
    assert_select "h3", "Timmy"
    # Inactive should not
    assert_select "h3", text: "Grandpa", count: 0
  end

  test "should get new dietary profile form" do
    sign_in_as(@session)
    get "#{account_path_prefix}/dietary_profiles/new"
    assert_response :success
    assert_select "h1", "New Dietary Profile"
  end

  test "new form pre-fills account defaults" do
    @account.update!(default_diet_name: "Ketogenic (Keto)", default_daily_calories_target: 2000)
    sign_in_as(@session)
    get "#{account_path_prefix}/dietary_profiles/new"
    assert_response :success
    assert_select "select[name='dietary_profile[diet_name]'] option[selected]", "Ketogenic (Keto)"
  end

  test "should create dietary profile" do
    sign_in_as(@session)

    assert_difference "DietaryProfile.count" do
      post "#{account_path_prefix}/dietary_profiles", params: {
        dietary_profile: {
          name: "Baby",
          diet_name: "Standard / USDA Guidelines",
          daily_calories_target: 1200
        }
      }
    end

    assert_redirected_to "#{account_path_prefix}/dietary_profiles"
    new_profile = DietaryProfile.order(created_at: :desc).first
    assert_equal "Baby", new_profile.name
    assert_equal @account, new_profile.account
  end

  test "should reject invalid dietary profile" do
    sign_in_as(@session)

    assert_no_difference "DietaryProfile.count" do
      post "#{account_path_prefix}/dietary_profiles", params: {
        dietary_profile: { name: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit form" do
    sign_in_as(@session)
    get "#{account_path_prefix}/dietary_profiles/#{@profile.id}/edit"
    assert_response :success
    assert_select "h1", "Edit Dietary Profile"
  end

  test "should update dietary profile" do
    sign_in_as(@session)
    patch "#{account_path_prefix}/dietary_profiles/#{@profile.id}", params: {
      dietary_profile: { name: "Father" }
    }
    assert_redirected_to "#{account_path_prefix}/dietary_profiles"
    assert_equal "Father", @profile.reload.name
  end

  test "should create dietary profile without user (blank user_id)" do
    sign_in_as(@session)

    assert_difference "DietaryProfile.count" do
      post "#{account_path_prefix}/dietary_profiles", params: {
        dietary_profile: {
          name: "Toddler",
          diet_name: "Standard / USDA Guidelines",
          daily_calories_target: 1000,
          user_id: ""
        }
      }
    end

    assert_redirected_to "#{account_path_prefix}/dietary_profiles"
    new_profile = DietaryProfile.order(created_at: :desc).first
    assert_equal "Toddler", new_profile.name
    assert_nil new_profile.user_id
  end

  test "should update dietary profile clearing user_id with blank string" do
    sign_in_as(@session)

    assert @profile.user_id.present?

    patch "#{account_path_prefix}/dietary_profiles/#{@profile.id}", params: {
      dietary_profile: { user_id: "" }
    }

    assert_redirected_to "#{account_path_prefix}/dietary_profiles"
    assert_nil @profile.reload.user_id
  end

  test "should soft-delete dietary profile" do
    sign_in_as(@session)

    assert_no_difference "DietaryProfile.count" do
      delete "#{account_path_prefix}/dietary_profiles/#{@profile.id}"
    end

    assert_redirected_to "#{account_path_prefix}/dietary_profiles"
    assert_not @profile.reload.active
  end
end

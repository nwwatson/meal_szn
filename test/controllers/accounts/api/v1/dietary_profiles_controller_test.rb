require "test_helper"

class Accounts::Api::V1::DietaryProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @read_token = identity_access_tokens(:read_token)
    @write_token = identity_access_tokens(:write_token)
    @profile = dietary_profiles(:dad)
  end

  def auth_header(token)
    { "Authorization" => "Bearer #{token.token}" }
  end

  def api_url(path = "")
    "/#{@account.external_account_id}/api/v1/dietary_profiles#{path}"
  end

  # ===========================================================================
  # GET index
  # ===========================================================================

  test "index requires authentication" do
    get api_url
    assert_response :unauthorized
  end

  test "index returns active dietary profiles" do
    get api_url, headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert json["dietary_profiles"].is_a?(Array)
    names = json["dietary_profiles"].map { |p| p["name"] }
    assert_includes names, "Dad"
    assert_includes names, "Mom"
    assert_not_includes names, "Grandpa" # inactive
  end

  test "index includes diet_names in meta" do
    get api_url, headers: auth_header(@read_token)

    json = JSON.parse(response.body)
    assert json["meta"]["diet_names"].is_a?(Array)
    assert json["meta"]["diet_names"].length > 0
  end

  test "index includes macro_targets for profiles with diet" do
    get api_url, headers: auth_header(@read_token)

    json = JSON.parse(response.body)
    dad = json["dietary_profiles"].find { |p| p["name"] == "Dad" }
    assert dad["macro_targets"].present?
    assert dad["macro_targets"]["calories"].present?
  end

  # ===========================================================================
  # GET show
  # ===========================================================================

  test "show returns single profile" do
    get api_url("/#{@profile.id}"), headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @profile.id, json["dietary_profile"]["id"]
    assert_equal "Dad", json["dietary_profile"]["name"]
  end

  test "show returns 404 for nonexistent profile" do
    get api_url("/nonexistent"), headers: auth_header(@read_token)
    assert_response :not_found
  end

  # ===========================================================================
  # POST create
  # ===========================================================================

  test "create requires write permission" do
    post api_url,
         params: { dietary_profile: { name: "Test" } },
         headers: auth_header(@read_token),
         as: :json
    assert_response :forbidden
  end

  test "create creates a dietary profile" do
    assert_difference "DietaryProfile.count" do
      post api_url,
           params: {
             dietary_profile: {
               name: "Toddler",
               diet_name: "Ketogenic (Keto)",
               daily_calories_target: 1200
             }
           },
           headers: auth_header(@write_token),
           as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "Toddler", json["dietary_profile"]["name"]
    assert_equal 1200, json["dietary_profile"]["daily_calories_target"]
  end

  test "create returns validation errors" do
    post api_url,
         params: { dietary_profile: { name: "" } },
         headers: auth_header(@write_token),
         as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["errors"].any? { |e| e.include?("Name") }
  end

  test "create rejects duplicate name" do
    post api_url,
         params: { dietary_profile: { name: "Dad" } },
         headers: auth_header(@write_token),
         as: :json

    assert_response :unprocessable_entity
  end

  # ===========================================================================
  # PATCH update
  # ===========================================================================

  test "update requires write permission" do
    patch api_url("/#{@profile.id}"),
          params: { dietary_profile: { name: "Updated" } },
          headers: auth_header(@read_token),
          as: :json
    assert_response :forbidden
  end

  test "update modifies the profile" do
    patch api_url("/#{@profile.id}"),
          params: { dietary_profile: { daily_calories_target: 2200 } },
          headers: auth_header(@write_token),
          as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2200, json["dietary_profile"]["daily_calories_target"]
  end

  # ===========================================================================
  # DELETE destroy
  # ===========================================================================

  test "destroy requires write permission" do
    delete api_url("/#{@profile.id}"), headers: auth_header(@read_token)
    assert_response :forbidden
  end

  test "destroy soft-deletes the profile" do
    assert_no_difference "DietaryProfile.count" do
      delete api_url("/#{@profile.id}"), headers: auth_header(@write_token)
    end

    assert_response :no_content
    assert_not @profile.reload.active
  end
end

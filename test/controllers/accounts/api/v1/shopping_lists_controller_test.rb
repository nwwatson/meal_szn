require "test_helper"

class Accounts::Api::V1::ShoppingListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @read_token = identity_access_tokens(:read_token)
    @write_token = identity_access_tokens(:write_token)
    @meal_plan = meal_plans(:one)
    @shopping_list = shopping_lists(:one)
    @unchecked_item = shopping_list_items(:salmon)
    @checked_item = shopping_list_items(:eggs)
  end

  def auth_header(token)
    { "Authorization" => "Bearer #{token.token}" }
  end

  def shopping_list_url(meal_plan_id = @meal_plan.id)
    "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan_id}/shopping_list"
  end

  def toggle_url(meal_plan_id, item_id)
    "/#{@account.external_account_id}/api/v1/meal_plans/#{meal_plan_id}/shopping_list/items/#{item_id}/toggle"
  end

  # ===========================================================================
  # GET show
  # ===========================================================================

  test "show requires authentication" do
    get shopping_list_url
    assert_response :unauthorized
  end

  test "show returns shopping list with items" do
    get shopping_list_url, headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)
    list = json["shopping_list"]
    assert_equal @shopping_list.id, list["id"]
    assert list["items"].is_a?(Array)
    assert list["items"].length > 0
    assert list.key?("checked_count")
    assert list.key?("total_count")
    assert list.key?("all_checked")
  end

  test "show returns items with details" do
    get shopping_list_url, headers: auth_header(@read_token)

    json = JSON.parse(response.body)
    item = json["shopping_list"]["items"].find { |i| i["name"] == "Salmon Fillet" }
    assert item.present?
    assert_equal "2", item["quantity"]
    assert_equal "lbs", item["unit"]
    assert_equal false, item["checked"]
    assert item["display_text"].present?
  end

  test "show returns 404 when no shopping list exists" do
    past_plan = meal_plans(:past)
    get shopping_list_url(past_plan.id), headers: auth_header(@read_token)

    assert_response :not_found
  end

  test "show returns 404 for nonexistent meal plan" do
    get shopping_list_url("nonexistent"), headers: auth_header(@read_token)
    assert_response :not_found
  end

  # ===========================================================================
  # POST create
  # ===========================================================================

  test "create requires authentication" do
    post shopping_list_url
    assert_response :unauthorized
  end

  test "create requires write permission" do
    post shopping_list_url, headers: auth_header(@read_token)
    assert_response :forbidden
  end

  test "create generates a shopping list" do
    assert_difference "ShoppingList.count" do
      post shopping_list_url, headers: auth_header(@write_token)
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert json["shopping_list"]["id"].present?
    assert json["shopping_list"]["items"].is_a?(Array)
  end

  # ===========================================================================
  # PATCH toggle
  # ===========================================================================

  test "toggle requires authentication" do
    patch toggle_url(@meal_plan.id, @unchecked_item.id)
    assert_response :unauthorized
  end

  test "toggle requires write permission" do
    patch toggle_url(@meal_plan.id, @unchecked_item.id), headers: auth_header(@read_token)
    assert_response :forbidden
  end

  test "toggle checks an unchecked item" do
    assert_not @unchecked_item.checked

    patch toggle_url(@meal_plan.id, @unchecked_item.id), headers: auth_header(@write_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert json["checked"]
    assert @unchecked_item.reload.checked
  end

  test "toggle unchecks a checked item" do
    assert @checked_item.checked

    patch toggle_url(@meal_plan.id, @checked_item.id), headers: auth_header(@write_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_not json["checked"]
    assert_not @checked_item.reload.checked
  end

  test "toggle returns 404 for item in different meal plan" do
    past_plan = meal_plans(:past)
    patch toggle_url(past_plan.id, @unchecked_item.id), headers: auth_header(@write_token)

    assert_response :not_found
  end
end

require "test_helper"

class PwaControllerTest < ActionDispatch::IntegrationTest
  test "manifest returns JSON with correct content type" do
    get pwa_manifest_path(format: :json)
    assert_response :success
    assert_equal "application/manifest+json; charset=utf-8", response.content_type

    json = JSON.parse(response.body)
    assert_equal "MealSzn", json["name"]
    assert_equal "MealSzn", json["short_name"]
    assert_equal "standalone", json["display"]
    assert_equal "#c2582a", json["theme_color"]
    assert_equal "#fdfbf7", json["background_color"]
    assert json["icons"].is_a?(Array)
    assert json["icons"].size >= 2
  end

  test "service worker returns JavaScript with correct headers" do
    get pwa_service_worker_path
    assert_response :success
    assert_equal "application/javascript; charset=utf-8", response.content_type
    assert_equal "/", response.headers["Service-Worker-Allowed"]
    assert_equal "no-cache", response.headers["Cache-Control"]
    assert_includes response.body, "CACHE_VERSION"
    assert_includes response.body, "addEventListener"
  end

  test "manifest includes required PWA fields" do
    get pwa_manifest_path(format: :json)
    json = JSON.parse(response.body)

    assert json.key?("name")
    assert json.key?("start_url")
    assert json.key?("display")
    assert json.key?("icons")
    assert json.key?("theme_color")
    assert json.key?("background_color")
  end

  test "manifest icons include at least one maskable icon" do
    get pwa_manifest_path(format: :json)
    json = JSON.parse(response.body)

    maskable = json["icons"].select { |i| i["purpose"] == "maskable" }
    assert maskable.any?, "Manifest should include at least one maskable icon"
  end

  test "service worker handles caching strategies" do
    get pwa_service_worker_path
    assert_includes response.body, "STATIC_CACHE"
    assert_includes response.body, "DYNAMIC_CACHE"
    assert_includes response.body, "SHOPPING_CACHE"
    assert_includes response.body, "networkFirst"
    assert_includes response.body, "cacheFirst"
  end
end

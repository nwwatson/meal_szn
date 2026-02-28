require "test_helper"

class AiRateLimitedApiTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @write_token = identity_access_tokens(:write_token)
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  def auth_header
    { "Authorization" => "Bearer #{@write_token.token}" }
  end

  # ===========================================================================
  # API: Recipe import rate limiting
  # ===========================================================================

  test "API import_url returns 429 when rate limit exceeded" do
    exhaust_limit!(:recipe_import)

    post "/#{@account.external_account_id}/api/v1/recipes/import_url",
         params: { url: "https://example.com/recipe" },
         headers: auth_header,
         as: :json

    assert_response :too_many_requests
    json = JSON.parse(response.body)
    assert_equal "Rate limit exceeded. Please try again later.", json["error"]
    assert json["retry_after"].is_a?(Integer)
    assert response.headers["Retry-After"].present?
  end

  test "API import_photo returns 429 when rate limit exceeded" do
    exhaust_limit!(:recipe_import)

    post "/#{@account.external_account_id}/api/v1/recipes/import_photo",
         params: { photos: [ fixture_file_upload("test/fixtures/files/test_image.jpg", "image/jpeg") ] },
         headers: auth_header

    assert_response :too_many_requests
  end

  test "API import_url succeeds when under limit" do
    post "/#{@account.external_account_id}/api/v1/recipes/import_url",
         params: { url: "https://example.com/recipe" },
         headers: auth_header,
         as: :json

    assert_response :created
  end

  # ===========================================================================
  # API: Meal plan generation rate limiting
  # ===========================================================================

  test "API generate returns 429 when rate limit exceeded" do
    exhaust_limit!(:meal_plan_generation)

    post "/#{@account.external_account_id}/api/v1/meal_plans/generate",
         params: {
           meal_plan: {
             name: "Test Plan",
             start_date: Date.today,
             end_date: Date.today + 6.days
           }
         },
         headers: auth_header,
         as: :json

    assert_response :too_many_requests
    json = JSON.parse(response.body)
    assert json["retry_after"].present?
    assert response.headers["Retry-After"].present?
  end

  test "API generate succeeds when under limit" do
    assert_enqueued_with(job: MealPlanGenerationJob) do
      post "/#{@account.external_account_id}/api/v1/meal_plans/generate",
           params: {
             meal_plan: {
               name: "Test Plan",
               start_date: Date.today,
               end_date: Date.today + 6.days
             }
           },
           headers: auth_header,
           as: :json
    end

    assert_response :created
  end

  # ===========================================================================
  # Rate limit increments on success
  # ===========================================================================

  test "successful request decrements remaining count" do
    limiter = Ai::RateLimiter.new(@account)
    initial_remaining = limiter.remaining(:recipe_import)

    post "/#{@account.external_account_id}/api/v1/recipes/import_url",
         params: { url: "https://example.com/recipe" },
         headers: auth_header,
         as: :json

    assert_response :created
    assert_equal initial_remaining - 1, limiter.remaining(:recipe_import)
  end

  private

  def exhaust_limit!(feature)
    limiter = Ai::RateLimiter.new(@account)
    Ai.rate_limits[feature][:limit].times { limiter.increment!(feature) }
  end
end

class AiRateLimitedWebTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
    sign_in_as(@session)
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  # ===========================================================================
  # Web: Recipe import rate limiting
  # ===========================================================================

  test "web start_import redirects with flash when rate limit exceeded" do
    exhaust_limit!(:recipe_import)

    post "/#{@account.external_account_id}/recipes/start_import",
         params: { url: "https://example.com/recipe" }

    assert_response :redirect
    assert_match(/limit/, flash[:alert])
  end

  test "web start_photo_import redirects when rate limit exceeded" do
    exhaust_limit!(:recipe_import)

    post "/#{@account.external_account_id}/recipes/start_photo_import",
         params: { photos: [ fixture_file_upload("test/fixtures/files/test_image.jpg", "image/jpeg") ] }

    assert_response :redirect
    assert_match(/limit/, flash[:alert])
  end

  # ===========================================================================
  # Web: Quick entry rate limiting
  # ===========================================================================

  test "web start_quick_entry redirects when rate limit exceeded" do
    exhaust_limit!(:quick_entry)

    post "/#{@account.external_account_id}/recipes/start_quick_entry",
         params: { description: "A keto pizza" }

    assert_response :redirect
    assert_match(/limit/, flash[:alert])
  end

  # ===========================================================================
  # Web: Meal plan generation rate limiting
  # ===========================================================================

  test "web start_generate redirects when rate limit exceeded" do
    exhaust_limit!(:meal_plan_generation)

    next_monday = Date.current.beginning_of_week + 7.days
    post "/#{@account.external_account_id}/meal_plans/start_generate",
         params: {
           meal_plan: {
             name: "Test Plan",
             start_date: next_monday,
             end_date: next_monday + 6.days
           }
         }

    assert_response :redirect
    assert_match(/limit/, flash[:alert])
  end

  private

  def exhaust_limit!(feature)
    limiter = Ai::RateLimiter.new(@account)
    Ai.rate_limits[feature][:limit].times { limiter.increment!(feature) }
  end
end

require "test_helper"

class Accounts::Api::V1::RecipeImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @read_token = identity_access_tokens(:read_token)
    @write_token = identity_access_tokens(:write_token)
    @pending_task = ai_task_statuses(:pending_task)
    @completed_import_task = ai_task_statuses(:completed_import_task)
    @failed_task = ai_task_statuses(:failed_task)
  end

  def auth_header(token)
    { "Authorization" => "Bearer #{token.token}" }
  end

  def api_path(action, **opts)
    case action
    when :import_url
      "/#{@account.external_account_id}/api/v1/recipes/import_url"
    when :import_photo
      "/#{@account.external_account_id}/api/v1/recipes/import_photo"
    when :import_status
      "/#{@account.external_account_id}/api/v1/recipes/import_status/#{opts[:task_id]}"
    when :import_confirm
      "/#{@account.external_account_id}/api/v1/recipes/import_confirm/#{opts[:task_id]}"
    end
  end

  # ===========================================================================
  # POST import_url
  # ===========================================================================

  test "import_url requires authentication" do
    post api_path(:import_url), params: { url: "https://example.com/recipe" }, as: :json
    assert_response :unauthorized
  end

  test "import_url requires write permission" do
    post api_path(:import_url),
         params: { url: "https://example.com/recipe" },
         headers: auth_header(@read_token),
         as: :json
    assert_response :forbidden
  end

  test "import_url returns 400 when url is blank" do
    post api_path(:import_url),
         params: { url: "" },
         headers: auth_header(@write_token),
         as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal "URL is required", json["error"]
  end

  test "import_url creates task and enqueues job" do
    assert_difference "AiTaskStatus.count" do
      assert_enqueued_with(job: RecipeImportJob) do
        post api_path(:import_url),
             params: { url: "https://example.com/recipe" },
             headers: auth_header(@write_token),
             as: :json
      end
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert json["task_id"].present?
    assert_equal "pending", json["status"]
  end

  # ===========================================================================
  # POST import_photo
  # ===========================================================================

  test "import_photo requires authentication" do
    post api_path(:import_photo)
    assert_response :unauthorized
  end

  test "import_photo requires write permission" do
    photo = fixture_file_upload("test/fixtures/files/test_image.jpg", "image/jpeg")
    post api_path(:import_photo),
         params: { photos: [ photo ] },
         headers: auth_header(@read_token)
    assert_response :forbidden
  end

  test "import_photo returns 400 when no photos provided" do
    post api_path(:import_photo),
         headers: auth_header(@write_token),
         as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal "At least one photo is required", json["error"]
  end

  test "import_photo creates task and enqueues job" do
    photo = fixture_file_upload("test/fixtures/files/test_image.jpg", "image/jpeg")

    assert_difference "AiTaskStatus.count" do
      assert_enqueued_with(job: RecipeImportPhotoJob) do
        post api_path(:import_photo),
             params: { photos: [ photo ] },
             headers: auth_header(@write_token)
      end
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert json["task_id"].present?
    assert_equal "pending", json["status"]
  end

  # ===========================================================================
  # GET import_status
  # ===========================================================================

  test "import_status requires authentication" do
    get api_path(:import_status, task_id: @pending_task.id)
    assert_response :unauthorized
  end

  test "import_status returns 404 for nonexistent task" do
    get api_path(:import_status, task_id: "nonexistent"),
        headers: auth_header(@read_token)
    assert_response :not_found
  end

  test "import_status returns pending task" do
    get api_path(:import_status, task_id: @pending_task.id),
        headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @pending_task.id, json["task_id"]
    assert_equal "pending", json["status"]
    assert_equal 0, json["progress_percentage"]
    assert_nil json["result"]
  end

  test "import_status returns completed task with result" do
    get api_path(:import_status, task_id: @completed_import_task.id),
        headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "completed", json["status"]
    assert_equal 100, json["progress_percentage"]
    assert json["result"].present?
    assert_equal "Imported Keto Pancakes", json["result"]["title"]
  end

  test "import_status returns failed task with error message" do
    get api_path(:import_status, task_id: @failed_task.id),
        headers: auth_header(@read_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "failed", json["status"]
    assert_equal "API rate limit exceeded", json["error_message"]
  end

  # ===========================================================================
  # POST import_confirm
  # ===========================================================================

  test "import_confirm requires authentication" do
    post api_path(:import_confirm, task_id: @completed_import_task.id)
    assert_response :unauthorized
  end

  test "import_confirm requires write permission" do
    post api_path(:import_confirm, task_id: @completed_import_task.id),
         headers: auth_header(@read_token),
         as: :json
    assert_response :forbidden
  end

  test "import_confirm returns 404 for nonexistent task" do
    post api_path(:import_confirm, task_id: "nonexistent"),
         headers: auth_header(@write_token),
         as: :json
    assert_response :not_found
  end

  test "import_confirm rejects incomplete task" do
    post api_path(:import_confirm, task_id: @pending_task.id),
         headers: auth_header(@write_token),
         as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "Task is not yet completed", json["error"]
  end

  test "import_confirm creates recipe from completed task" do
    assert_difference "Recipe.count" do
      post api_path(:import_confirm, task_id: @completed_import_task.id),
           headers: auth_header(@write_token),
           as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "Imported Keto Pancakes", json["recipe"]["title"]
    assert_equal 4, json["recipe"]["servings"]
    assert_equal 3, json["recipe"]["ingredients"].length
    assert_equal 2, json["recipe"]["instructions"].length
    assert_equal 350, json["recipe"]["nutrition"]["calories"]
  end

  test "import_confirm allows overriding recipe fields" do
    assert_difference "Recipe.count" do
      post api_path(:import_confirm, task_id: @completed_import_task.id),
           params: { recipe: { title: "My Custom Title", category: "breakfast", servings: 2 } },
           headers: auth_header(@write_token),
           as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "My Custom Title", json["recipe"]["title"]
    assert_equal "breakfast", json["recipe"]["category"]
    assert_equal 2, json["recipe"]["servings"]
  end
end

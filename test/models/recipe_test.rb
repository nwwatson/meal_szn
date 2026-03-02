require "test_helper"

class RecipeTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "belongs to account" do
    recipe = recipes(:one)
    assert_respond_to recipe, :account
    assert_not_nil recipe.account
  end

  test "has many ingredients" do
    recipe = recipes(:one)
    assert_respond_to recipe, :ingredients
  end

  test "has many instructions" do
    recipe = recipes(:one)
    assert_respond_to recipe, :instructions
  end

  test "has one nutrition_data" do
    recipe = recipes(:one)
    assert_respond_to recipe, :nutrition_data
  end

  test "has many tips" do
    recipe = recipes(:one)
    assert_respond_to recipe, :tips
  end

  test "requires title" do
    recipe = Recipe.new(account: accounts(:one), category: :dinner)
    assert_not recipe.valid?
    assert_includes recipe.errors[:title], "can't be blank"
  end

  test "requires category" do
    recipe = Recipe.new(account: accounts(:one), title: "Test Recipe", category: nil)
    assert_not recipe.valid?
    assert_includes recipe.errors[:category], "can't be blank"
  end

  test "category enum includes expected values" do
    assert_equal %w[breakfast lunch dinner sides snacks sauces], Recipe.categories.keys
  end

  test "by_category scope filters recipes" do
    account = accounts(:one)
    breakfast = Recipe.create!(account: account, title: "Eggs", category: :breakfast)
    dinner = Recipe.create!(account: account, title: "Salmon", category: :dinner)

    assert_includes Recipe.by_category(:breakfast), breakfast
    assert_not_includes Recipe.by_category(:breakfast), dinner
  end

  test "total_time calculates prep + cook time" do
    recipe = Recipe.new(prep_time: 15, cook_time: 30)
    assert_equal 45, recipe.total_time
  end

  test "total_time handles nil values" do
    recipe = Recipe.new(prep_time: nil, cook_time: 30)
    assert_equal 30, recipe.total_time

    recipe = Recipe.new(prep_time: 15, cook_time: nil)
    assert_equal 15, recipe.total_time
  end

  test "ingredients_summary returns comma-separated names" do
    recipe = recipes(:one)
    recipe.ingredients.create!(name: "Salmon", quantity: "4", unit: "fillets")
    recipe.ingredients.create!(name: "Butter", quantity: "2", unit: "tbsp")

    summary = recipe.ingredients_summary
    assert_includes summary, "Salmon"
    assert_includes summary, "Butter"
  end

  test "to_api_response includes all recipe data" do
    recipe = recipes(:one)
    response = recipe.to_api_response

    assert_equal recipe.id, response[:id]
    assert_equal recipe.title, response[:title]
    assert_equal recipe.category, response[:category]
    assert response[:created_at].present?
  end

  test "to_meal_planning_response includes nutrition data" do
    recipe = recipes(:one)
    response = recipe.to_meal_planning_response

    assert_equal recipe.id, response[:id]
    assert_equal recipe.title, response[:title]
    assert_equal recipe.category, response[:category]
    assert response[:nutrition_per_serving].present?
    assert_nil response[:url], "url should not be included in meal planning response"
    assert_nil response[:ingredients_summary], "ingredients_summary should not be included"
  end

  test "has many tags through recipe_tags" do
    recipe = recipes(:one)
    assert_includes recipe.tags, tags(:keto)
    assert_includes recipe.tags, tags(:quick)
  end

  test "by_tags scope filters recipes by tag ids" do
    keto_tag = tags(:keto)
    dinner_party_tag = tags(:dinner_party)

    results = Recipe.by_tags([ keto_tag.id ])
    assert_includes results, recipes(:one)
    assert_includes results, recipes(:two)
    assert_not_includes results, recipes(:side_dish)

    results = Recipe.by_tags([ dinner_party_tag.id ])
    assert_empty results
  end

  test "by_tags scope returns all when nil" do
    assert_equal Recipe.all.to_a, Recipe.by_tags(nil).to_a
  end

  test "tag_list returns comma-separated tag names" do
    recipe = recipes(:one)
    list = recipe.tag_list
    assert_includes list, "keto"
    assert_includes list, "quick"
  end

  test "sync_tags_from_list creates and assigns tags" do
    account = accounts(:one)
    recipe = recipes(:side_dish)

    recipe.sync_tags_from_list("salad, tex-mex", account)
    assert_equal 2, recipe.tags.count
    assert_includes recipe.tags.pluck(:name), "salad"
    assert_includes recipe.tags.pluck(:name), "tex-mex"
  end

  test "sync_tags_from_list finds existing tags" do
    account = accounts(:one)
    recipe = recipes(:side_dish)

    assert_no_difference "Tag.count" do
      recipe.sync_tags_from_list("keto", account)
    end
    assert_includes recipe.tags, tags(:keto)
  end

  test "sync_tags_from_list removes old tags" do
    recipe = recipes(:one)
    account = accounts(:one)

    recipe.sync_tags_from_list("keto", account)
    assert_equal 1, recipe.tags.count
    assert_equal [ "keto" ], recipe.tags.pluck(:name)
  end

  test "sync_tags_from_list with blank string clears tags" do
    recipe = recipes(:one)
    account = accounts(:one)

    recipe.sync_tags_from_list("", account)
    assert_empty recipe.tags
  end

  test "to_api_response includes tags" do
    recipe = recipes(:one)
    response = recipe.to_api_response

    assert response[:tags].is_a?(Array)
    assert_includes response[:tags], "keto"
  end

  test "can have an attached image" do
    recipe = recipes(:one)
    assert_respond_to recipe, :image
    assert_not recipe.image.attached?

    recipe.image.attach(
      io: StringIO.new("fake image data"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )
    assert recipe.image.attached?
  end

  test "can have multiple attached images" do
    recipe = recipes(:one)
    assert_respond_to recipe, :images

    # Create attachment directly
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake"), filename: "test.jpg", content_type: "image/jpeg"
    )
    ActiveStorage::Attachment.create!(
      name: "images", record: recipe, blob: blob
    )
    assert_equal 1, recipe.reload.images.count

    blob2 = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake2"), filename: "test2.png", content_type: "image/png"
    )
    ActiveStorage::Attachment.create!(
      name: "images", record: recipe, blob: blob2
    )
    assert_equal 2, recipe.reload.images.count
  end

  test "image defines named variants" do
    recipe = recipes(:one)
    recipe.image.attach(
      io: StringIO.new("fake image data"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )
    assert recipe.image.variant(:thumbnail)
    assert recipe.image.variant(:card)
    assert recipe.image.variant(:full)
  end

  test "rejects image with invalid content type" do
    recipe = recipes(:one)
    recipe.image.attach(
      io: StringIO.new("not an image"),
      filename: "test.txt",
      content_type: "text/plain"
    )
    assert_not recipe.valid?
    assert_includes recipe.errors[:image], "must be a JPEG, PNG, WebP, or GIF file"
  end

  test "rejects image exceeding 10MB" do
    recipe = recipes(:one)
    recipe.image.attach(
      io: StringIO.new("x" * (11 * 1024 * 1024)),
      filename: "huge.jpg",
      content_type: "image/jpeg"
    )
    assert_not recipe.valid?
    assert_includes recipe.errors[:image], "must be less than 10MB"
  end

  test "accepts valid image types" do
    recipe = recipes(:one)
    %w[image/jpeg image/png image/webp image/gif].each do |type|
      recipe.image.attach(
        io: StringIO.new("fake"),
        filename: "test.#{type.split('/').last}",
        content_type: type
      )
      recipe.valid?
      assert_empty recipe.errors[:image], "Expected #{type} to be accepted"
    end
  end

  test "rejects additional images with invalid content type" do
    recipe = recipes(:one)
    recipe.images.attach(
      io: StringIO.new("not an image"),
      filename: "bad.txt",
      content_type: "text/plain"
    )
    assert_not recipe.valid?
    assert_includes recipe.errors[:images], "must be a JPEG, PNG, WebP, or GIF file"
  end

  test "rejects additional images exceeding 10MB" do
    recipe = recipes(:one)
    recipe.images.attach(
      io: StringIO.new("x" * (11 * 1024 * 1024)),
      filename: "huge.jpg",
      content_type: "image/jpeg"
    )
    assert_not recipe.valid?
    assert_includes recipe.errors[:images], "must be less than 10MB"
  end

  test "to_meal_planning_response includes tags" do
    recipe = recipes(:one)
    response = recipe.to_meal_planning_response

    assert response[:tags].is_a?(Array)
    assert_includes response[:tags], "keto"
  end

  test "enqueues nutrition calculation job on create with ingredients" do
    account = accounts(:one)

    assert_enqueued_with(job: NutritionCalculationJob) do
      account.recipes.create!(
        title: "Auto Calc Recipe",
        category: :breakfast,
        servings: 2,
        ingredients_attributes: [
          { name: "Eggs", quantity: "2", unit: "large", display_order: 0 }
        ]
      )
    end
  end

  test "does not enqueue nutrition calculation job without ingredients" do
    account = accounts(:one)

    assert_no_enqueued_jobs(only: NutritionCalculationJob) do
      account.recipes.create!(
        title: "Empty Recipe",
        category: :breakfast,
        servings: 2
      )
    end
  end

  # --- Rating tests ---

  test "rating validates inclusion in 1 to 5" do
    recipe = recipes(:one)

    (1..5).each do |r|
      recipe.rating = r
      assert recipe.valid?, "Expected rating #{r} to be valid"
    end

    recipe.rating = 0
    assert_not recipe.valid?
    recipe.rating = 6
    assert_not recipe.valid?
    recipe.rating = -1
    assert_not recipe.valid?
  end

  test "rating allows nil" do
    recipe = recipes(:one)
    recipe.rating = nil
    assert recipe.valid?
  end

  test "by_min_rating scope returns recipes at or above threshold" do
    account = accounts(:one)
    r5 = account.recipes.create!(title: "Five Star", category: :dinner, rating: 5)
    r3 = account.recipes.create!(title: "Three Star", category: :dinner, rating: 3)
    r1 = account.recipes.create!(title: "One Star", category: :dinner, rating: 1)

    results = Recipe.by_min_rating(4)
    assert_includes results, r5
    assert_not_includes results, r3
    assert_not_includes results, r1

    results = Recipe.by_min_rating(3)
    assert_includes results, r5
    assert_includes results, r3
    assert_not_includes results, r1
  ensure
    [ r5, r3, r1 ].compact.each(&:destroy)
  end

  test "by_min_rating scope returns all when nil" do
    assert_equal Recipe.all.to_a, Recipe.by_min_rating(nil).to_a
  end

  test "sorted_by highest_rated orders 5-star first and unrated mid" do
    account = accounts(:one)
    r5 = account.recipes.create!(title: "Five Star", category: :dinner, rating: 5)
    r_nil = account.recipes.create!(title: "Unrated", category: :dinner, rating: nil)
    r2 = account.recipes.create!(title: "Two Star", category: :dinner, rating: 2)

    results = account.recipes.sorted_by("highest_rated").to_a
    r5_idx = results.index(r5)
    r_nil_idx = results.index(r_nil)
    r2_idx = results.index(r2)

    assert r5_idx < r_nil_idx, "5-star should come before unrated"
    assert r_nil_idx < r2_idx, "Unrated (treated as 3) should come before 2-star"
  ensure
    [ r5, r_nil, r2 ].compact.each(&:destroy)
  end

  test "to_api_response includes rating" do
    recipe = recipes(:one)
    recipe.update!(rating: 4)
    response = recipe.to_api_response

    assert_equal 4, response[:rating]
  end

  test "to_meal_planning_response includes rating" do
    recipe = recipes(:one)
    recipe.update!(rating: 5)
    response = recipe.to_meal_planning_response

    assert_equal 5, response[:rating]
  end

  test "does not enqueue nutrition calculation when manual nutrition exists" do
    recipe = recipes(:one)
    # recipes(:one) has nutrition_data with auto_calculated: false

    assert_no_enqueued_jobs(only: NutritionCalculationJob) do
      recipe.update!(title: "Updated Title")
    end
  end
end

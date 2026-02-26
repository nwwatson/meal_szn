# frozen_string_literal: true

require "test_helper"
require "net/http"

class RecipeImport::UrlFetcherTest < ActiveSupport::TestCase
  test "raises FetchError for invalid scheme" do
    assert_raises(RecipeImport::UrlFetcher::FetchError) do
      RecipeImport::UrlFetcher.new("ftp://example.com/recipe").fetch
    end
  end

  test "raises FetchError for non-URL string" do
    assert_raises(RecipeImport::UrlFetcher::FetchError) do
      RecipeImport::UrlFetcher.new("not a url").fetch
    end
  end

  test "raises FetchError for blank URL" do
    assert_raises(RecipeImport::UrlFetcher::FetchError) do
      RecipeImport::UrlFetcher.new("").fetch
    end
  end

  test "constants are properly set" do
    assert_equal 5, RecipeImport::UrlFetcher::MAX_REDIRECTS
    assert_equal 15, RecipeImport::UrlFetcher::TIMEOUT
    assert_equal "MealSzn/1.0 RecipeImporter", RecipeImport::UrlFetcher::USER_AGENT
  end
end

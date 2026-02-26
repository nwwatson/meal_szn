# frozen_string_literal: true

require "test_helper"

class RecipeImport::UrlImporterTest < ActiveSupport::TestCase
  # Testable subclass that overrides URL fetching with predetermined HTML
  class TestableImporter < RecipeImport::UrlImporter
    attr_accessor :stub_html, :stub_fetch_error

    def initialize(url, stub_html: nil, stub_fetch_error: nil, ai_client: nil)
      super(url, ai_client: ai_client)
      @stub_html = stub_html
      @stub_fetch_error = stub_fetch_error
    end

    private

    # Override the fetch step to return stub HTML or raise
    def fetch_html
      raise RecipeImport::UrlFetcher::FetchError, @stub_fetch_error if @stub_fetch_error
      @stub_html
    end
  end

  def fixture_html(name)
    File.read(Rails.root.join("test/fixtures/files/#{name}"))
  end

  test "imports recipe from page with JSON-LD" do
    html = fixture_html("recipe_with_jsonld.html")
    importer = TestableImporter.new("https://example.com/recipe", stub_html: html)
    result = importer.import

    assert_equal "Keto Garlic Butter Salmon", result[:title]
    assert_equal :json_ld, importer.method_used
    assert_equal "https://example.com/recipe", result[:source]
  end

  test "sets source to the import URL" do
    html = fixture_html("recipe_with_jsonld.html")
    importer = TestableImporter.new("https://mysite.com/my-recipe", stub_html: html)
    result = importer.import
    assert_equal "https://mysite.com/my-recipe", result[:source]
  end

  test "raises ImportError when fetch fails" do
    importer = TestableImporter.new("https://example.com/404", stub_fetch_error: "Connection refused")

    error = assert_raises(RecipeImport::UrlImporter::ImportError) do
      importer.import
    end
    assert_match(/Failed to fetch URL/, error.message)
  end

  test "raises ImportError when no recipe data found" do
    empty_html = "<html><body><p>Just a blog post with no recipe.</p></body></html>"

    # Fake AI client that returns empty/blank result
    fake_ai_client = Class.new {
      def chat_with_tools(**args)
        { name: "extract_recipe", input: { "title" => "", "ingredients" => [], "instructions" => [] } }
      end
    }.new

    importer = TestableImporter.new("https://example.com/blog", stub_html: empty_html, ai_client: fake_ai_client)
    error = assert_raises(RecipeImport::UrlImporter::ImportError) do
      importer.import
    end
    assert_match(/Could not extract recipe data/, error.message)
  end

  test "falls back to AI when no JSON-LD present" do
    html = fixture_html("recipe_without_jsonld.html")

    fake_ai_client = Class.new {
      def chat_with_tools(**args)
        { name: "extract_recipe", input: {
          "title" => "Best Keto Pancakes",
          "ingredients" => [ "2 oz cream cheese", "2 eggs" ],
          "instructions" => [ "Blend ingredients", "Cook" ]
        } }
      end
    }.new

    importer = TestableImporter.new("https://example.com/pancakes", stub_html: html, ai_client: fake_ai_client)
    result = importer.import

    assert_equal "Best Keto Pancakes", result[:title]
    assert_equal :ai, importer.method_used
  end
end

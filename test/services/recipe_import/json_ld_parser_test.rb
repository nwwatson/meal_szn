# frozen_string_literal: true

require "test_helper"

class RecipeImport::JsonLdParserTest < ActiveSupport::TestCase
  def fixture_html(name)
    File.read(Rails.root.join("test/fixtures/files/#{name}"))
  end

  test "extracts recipe from valid JSON-LD" do
    result = RecipeImport::JsonLdParser.new(fixture_html("recipe_with_jsonld.html")).parse

    assert_not_nil result
    assert_equal "Keto Garlic Butter Salmon", result[:title]
    assert_equal 4, result[:servings]
    assert_equal 10, result[:prep_time]
    assert_equal 15, result[:cook_time]
    assert_equal 6, result[:ingredients].length
    assert_includes result[:ingredients].first, "salmon fillets"
    assert_equal 5, result[:instructions].length
    assert_equal 1, result[:instructions].first[:step_number]
    assert_includes result[:instructions].first[:instruction], "Pat salmon"
  end

  test "extracts nutrition from JSON-LD" do
    result = RecipeImport::JsonLdParser.new(fixture_html("recipe_with_jsonld.html")).parse

    assert_not_nil result[:nutrition]
    assert_equal 380.0, result[:nutrition][:calories]
    assert_equal 24.0, result[:nutrition][:fat]
    assert_equal 38.0, result[:nutrition][:protein]
    assert_equal 2.0, result[:nutrition][:carbs]
  end

  test "extracts source URL from JSON-LD" do
    result = RecipeImport::JsonLdParser.new(fixture_html("recipe_with_jsonld.html")).parse

    assert_equal "https://example.com/keto-garlic-butter-salmon", result[:source]
  end

  test "returns nil when no JSON-LD present" do
    result = RecipeImport::JsonLdParser.new(fixture_html("recipe_without_jsonld.html")).parse

    assert_nil result
  end

  test "returns nil for empty HTML" do
    result = RecipeImport::JsonLdParser.new("<html><body></body></html>").parse

    assert_nil result
  end

  test "handles JSON-LD with @graph array" do
    html = <<~HTML
      <html><head>
      <script type="application/ld+json">
      {"@context":"https://schema.org","@graph":[
        {"@type":"WebPage","name":"My Site"},
        {"@type":"Recipe","name":"Test Recipe","recipeIngredient":["1 cup water"],"recipeInstructions":["Boil water"]}
      ]}
      </script>
      </head><body></body></html>
    HTML

    result = RecipeImport::JsonLdParser.new(html).parse
    assert_not_nil result
    assert_equal "Test Recipe", result[:title]
  end

  test "parses ISO 8601 durations correctly" do
    html = <<~HTML
      <html><head>
      <script type="application/ld+json">
      {"@type":"Recipe","name":"Slow Cook","prepTime":"PT1H30M","cookTime":"PT2H","recipeIngredient":["water"],"recipeInstructions":["cook"]}
      </script>
      </head><body></body></html>
    HTML

    result = RecipeImport::JsonLdParser.new(html).parse
    assert_equal 90, result[:prep_time]
    assert_equal 120, result[:cook_time]
  end

  test "handles string instructions" do
    html = <<~HTML
      <html><head>
      <script type="application/ld+json">
      {"@type":"Recipe","name":"Simple","recipeIngredient":["1 egg"],"recipeInstructions":["Step one","Step two"]}
      </script>
      </head><body></body></html>
    HTML

    result = RecipeImport::JsonLdParser.new(html).parse
    assert_not_nil result
    assert_equal "Simple", result[:title]
    assert_equal 2, result[:instructions].length
    assert_equal "Step one", result[:instructions].first[:instruction]
  end

  test "extracts image URL as string" do
    result = RecipeImport::JsonLdParser.new(fixture_html("recipe_with_jsonld.html")).parse
    assert_equal "https://example.com/images/salmon.jpg", result[:image_url]
  end

  test "extracts image URL from ImageObject hash" do
    html = <<~HTML
      <html><head>
      <script type="application/ld+json">
      {"@type":"Recipe","name":"Test","image":{"@type":"ImageObject","url":"https://example.com/photo.jpg"},"recipeIngredient":["water"],"recipeInstructions":["cook"]}
      </script>
      </head><body></body></html>
    HTML

    result = RecipeImport::JsonLdParser.new(html).parse
    assert_equal "https://example.com/photo.jpg", result[:image_url]
  end

  test "extracts image URL from array" do
    html = <<~HTML
      <html><head>
      <script type="application/ld+json">
      {"@type":"Recipe","name":"Test","image":["https://example.com/1.jpg","https://example.com/2.jpg"],"recipeIngredient":["water"],"recipeInstructions":["cook"]}
      </script>
      </head><body></body></html>
    HTML

    result = RecipeImport::JsonLdParser.new(html).parse
    assert_equal "https://example.com/1.jpg", result[:image_url]
  end

  test "handles invalid JSON gracefully" do
    html = <<~HTML
      <html><head>
      <script type="application/ld+json">
      {not valid json at all}
      </script>
      </head><body></body></html>
    HTML

    result = RecipeImport::JsonLdParser.new(html).parse
    assert_nil result
  end
end

require "test_helper"

class MarkdownRecipeParserTest < ActiveSupport::TestCase
  SAMPLE_RECIPE = <<~MD
    # Peanut Butter Cup Smoothie

    A keto-friendly smoothie with chocolate and peanut butter flavors

    ## Source
    The Complete Ketogenic Guide for Beginners

    ## Servings
    2 servings

    ## Prep Time
    5 minutes

    ## Cook Time
    0 minutes

    ## Ingredients

    - 1 cup water
    - 1/4 cup coconut cream
    - 1 scoop chocolate protein powder
    - 2 tablespoons natural peanut butter
    - 3 ice cubes

    ## Instructions

    1. Put the water, coconut cream, protein powder, peanut butter, and ice in a blender and blend until smooth.

    2. Pour into 2 glasses and serve immediately.

    ## Nutrition (per serving)

    | Nutrient | Amount |
    |----------|--------|
    | Calories | 486 |
    | Fat | 40gg |
    | Protein | 30gg |
    | Total Carbs | 11gg |
    | Fiber | 5gg |
    | **Net Carbs** | **6gg** |
    | Sodium | 200mgmg |
    | Potassium | 400mgmg |
    | Magnesium | 85mgmg |

    ## Tips

    - For a more chocolaty taste, add cocoa powder
    - Use natural peanut butter without added sugars
  MD

  setup do
    @parser = MarkdownRecipeParser.new(SAMPLE_RECIPE)
    @result = @parser.parse
  end

  test "parses title" do
    assert_equal "Peanut Butter Cup Smoothie", @result[:title]
  end

  test "parses description" do
    assert_equal "A keto-friendly smoothie with chocolate and peanut butter flavors", @result[:description]
  end

  test "parses source" do
    assert_equal "The Complete Ketogenic Guide for Beginners", @result[:source]
  end

  test "parses servings as integer" do
    assert_equal 2, @result[:servings]
  end

  test "parses prep time in minutes" do
    assert_equal 5, @result[:prep_time]
  end

  test "parses cook time in minutes" do
    assert_equal 0, @result[:cook_time]
  end

  test "parses ingredients" do
    assert_equal 5, @result[:ingredients].length
  end

  test "parses ingredient with cup unit" do
    ing = @result[:ingredients][0]
    assert_equal "1", ing[:quantity]
    assert_equal "cups", ing[:unit]
    assert_equal "water", ing[:name]
  end

  test "parses ingredient with fraction quantity" do
    ing = @result[:ingredients][1]
    assert_equal "1/4", ing[:quantity]
    assert_equal "cups", ing[:unit]
    assert_equal "coconut cream", ing[:name]
  end

  test "parses ingredient with no recognized unit" do
    ing = @result[:ingredients][2]
    assert_equal "1", ing[:quantity]
    assert_nil ing[:unit]
    assert_equal "scoop chocolate protein powder", ing[:name]
  end

  test "parses ingredient with tablespoons" do
    ing = @result[:ingredients][3]
    assert_equal "2", ing[:quantity]
    assert_equal "tbsp", ing[:unit]
    assert_equal "natural peanut butter", ing[:name]
  end

  test "parses ingredient with just a number" do
    ing = @result[:ingredients][4]
    assert_equal "3", ing[:quantity]
    assert_nil ing[:unit]
    assert_equal "ice cubes", ing[:name]
  end

  test "parses instructions" do
    assert_equal 2, @result[:instructions].length
    assert_equal 1, @result[:instructions][0][:step_number]
    assert_match(/Put the water/, @result[:instructions][0][:instruction])
    assert_equal 2, @result[:instructions][1][:step_number]
  end

  test "parses nutrition stripping double unit suffixes" do
    nutrition = @result[:nutrition]
    assert_equal 486, nutrition[:calories]
    assert_equal 40.0, nutrition[:fat]
    assert_equal 30.0, nutrition[:protein]
    assert_equal 11.0, nutrition[:carbs]
    assert_equal 5.0, nutrition[:fiber]
    assert_equal 200, nutrition[:sodium]
    assert_equal 400, nutrition[:potassium]
    assert_equal 85, nutrition[:magnesium]
  end

  test "skips net carbs row in nutrition" do
    assert_nil @result[:nutrition][:net_carbs]
  end

  test "parses tips" do
    assert_equal 2, @result[:tips].length
    assert_match(/chocolaty taste/, @result[:tips][0])
    assert_match(/natural peanut butter/, @result[:tips][1])
  end

  test "parses servings with extra text" do
    parser = MarkdownRecipeParser.new("# Test\n\n## Servings\n18 servings (36 pieces)\n")
    result = parser.parse
    assert_equal 18, result[:servings]
  end

  test "parses cook time in hours" do
    parser = MarkdownRecipeParser.new("# Test\n\n## Cook Time\n1 hour\n")
    result = parser.parse
    assert_equal 60, result[:cook_time]
  end

  test "parses prep time with extra text" do
    parser = MarkdownRecipeParser.new("# Test\n\n## Prep Time\n10 minutes (plus 3 hours to chill)\n")
    result = parser.parse
    assert_equal 10, result[:prep_time]
  end

  test "parses cook time with parenthetical text" do
    parser = MarkdownRecipeParser.new("# Test\n\n## Cook Time\n0 minutes (1 hour 10 minutes resting time)\n")
    result = parser.parse
    assert_equal 0, result[:cook_time]
  end

  test "ignores ingredient sub-headers" do
    md = <<~MD
      # Test

      ## Ingredients

      ### For the Casserole
      - 1 cup cheese
      ### For the Topping
      - 2 tablespoons butter
    MD
    result = MarkdownRecipeParser.new(md).parse
    assert_equal 2, result[:ingredients].length
    assert_equal "cheese", result[:ingredients][0][:name]
    assert_equal "butter", result[:ingredients][1][:name]
  end

  test "parses ingredient with no quantity" do
    md = "# Test\n\n## Ingredients\n\n- Sea salt\n"
    result = MarkdownRecipeParser.new(md).parse
    ing = result[:ingredients].first
    assert_nil ing[:quantity]
    assert_nil ing[:unit]
    assert_equal "Sea salt", ing[:name]
  end

  test "parses ingredient starting with unit word" do
    md = "# Test\n\n## Ingredients\n\n- Pinch sea salt\n"
    result = MarkdownRecipeParser.new(md).parse
    ing = result[:ingredients].first
    assert_equal "1", ing[:quantity]
    assert_equal "pinch", ing[:unit]
    assert_equal "sea salt", ing[:name]
  end

  test "parses large as whole unit" do
    md = "# Test\n\n## Ingredients\n\n- 4 large eggs\n"
    result = MarkdownRecipeParser.new(md).parse
    ing = result[:ingredients].first
    assert_equal "4", ing[:quantity]
    assert_equal "whole", ing[:unit]
    assert_equal "large eggs", ing[:name]
  end

  test "parses mixed number quantity" do
    md = "# Test\n\n## Ingredients\n\n- 1 1/2 cup almond flour\n"
    result = MarkdownRecipeParser.new(md).parse
    ing = result[:ingredients].first
    assert_equal "1 1/2", ing[:quantity]
    assert_equal "cups", ing[:unit]
    assert_equal "almond flour", ing[:name]
  end

  test "parses parenthetical ingredient as name" do
    md = "# Test\n\n## Ingredients\n\n- 1 (4-ounce) chicken breast\n"
    result = MarkdownRecipeParser.new(md).parse
    ing = result[:ingredients].first
    assert_equal "1", ing[:quantity]
    assert_nil ing[:unit]
    assert_equal "(4-ounce) chicken breast", ing[:name]
  end

  test "stores juice-of style ingredient as full name" do
    md = "# Test\n\n## Ingredients\n\n- Juice of 1/2 lemon\n"
    result = MarkdownRecipeParser.new(md).parse
    ing = result[:ingredients].first
    assert_nil ing[:quantity]
    assert_nil ing[:unit]
    assert_equal "Juice of 1/2 lemon", ing[:name]
  end

  test "returns empty arrays for missing sections" do
    result = MarkdownRecipeParser.new("# Just a Title\n").parse
    assert_equal [], result[:ingredients]
    assert_equal [], result[:instructions]
    assert_equal [], result[:tips]
    assert_equal({}, result[:nutrition])
  end

  test "parses pound unit" do
    md = "# Test\n\n## Ingredients\n\n- 2 pounds ground beef\n"
    result = MarkdownRecipeParser.new(md).parse
    ing = result[:ingredients].first
    assert_equal "2", ing[:quantity]
    assert_equal "lb", ing[:unit]
    assert_equal "ground beef", ing[:name]
  end

  test "parses ounce unit" do
    md = "# Test\n\n## Ingredients\n\n- 8 ounces cream cheese\n"
    result = MarkdownRecipeParser.new(md).parse
    ing = result[:ingredients].first
    assert_equal "8", ing[:quantity]
    assert_equal "oz", ing[:unit]
    assert_equal "cream cheese", ing[:name]
  end

  test "parses teaspoon unit" do
    md = "# Test\n\n## Ingredients\n\n- 1 teaspoon salt\n"
    result = MarkdownRecipeParser.new(md).parse
    ing = result[:ingredients].first
    assert_equal "1", ing[:quantity]
    assert_equal "tsp", ing[:unit]
    assert_equal "salt", ing[:name]
  end

  test "parses clove unit" do
    md = "# Test\n\n## Ingredients\n\n- 2 cloves garlic\n"
    result = MarkdownRecipeParser.new(md).parse
    ing = result[:ingredients].first
    assert_equal "2", ing[:quantity]
    assert_equal "clove", ing[:unit]
    assert_equal "garlic", ing[:name]
  end

  test "parses dash unit" do
    md = "# Test\n\n## Ingredients\n\n- Dash cayenne pepper\n"
    result = MarkdownRecipeParser.new(md).parse
    ing = result[:ingredients].first
    assert_equal "1", ing[:quantity]
    assert_equal "dash", ing[:unit]
    assert_equal "cayenne pepper", ing[:name]
  end
end

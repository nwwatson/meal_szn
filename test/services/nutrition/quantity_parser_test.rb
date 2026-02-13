require "test_helper"

class Nutrition::QuantityParserTest < ActiveSupport::TestCase
  test "parses integer" do
    assert_equal 4.0, Nutrition::QuantityParser.parse("4")
  end

  test "parses decimal" do
    assert_equal 2.5, Nutrition::QuantityParser.parse("2.5")
  end

  test "parses simple fraction" do
    assert_in_delta 0.5, Nutrition::QuantityParser.parse("1/2"), 0.001
  end

  test "parses mixed number" do
    assert_in_delta 1.5, Nutrition::QuantityParser.parse("1 1/2"), 0.001
  end

  test "parses fraction 1/4" do
    assert_in_delta 0.25, Nutrition::QuantityParser.parse("1/4"), 0.001
  end

  test "parses fraction 3/4" do
    assert_in_delta 0.75, Nutrition::QuantityParser.parse("3/4"), 0.001
  end

  test "returns nil for nil input" do
    assert_nil Nutrition::QuantityParser.parse(nil)
  end

  test "returns nil for blank input" do
    assert_nil Nutrition::QuantityParser.parse("")
  end

  test "returns nil for non-numeric input" do
    assert_nil Nutrition::QuantityParser.parse("some text")
  end

  test "parses unicode fraction half" do
    assert_in_delta 0.5, Nutrition::QuantityParser.parse("½"), 0.001
  end

  test "parses unicode fraction with whole number" do
    assert_in_delta 1.5, Nutrition::QuantityParser.parse("1½"), 0.001
  end
end

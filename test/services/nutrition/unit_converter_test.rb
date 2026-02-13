require "test_helper"

class Nutrition::UnitConverterTest < ActiveSupport::TestCase
  test "converts grams" do
    assert_equal 100.0, Nutrition::UnitConverter.to_grams(100, "g")
  end

  test "converts kilograms" do
    assert_equal 1000.0, Nutrition::UnitConverter.to_grams(1, "kg")
  end

  test "converts ounces" do
    assert_in_delta 28.35, Nutrition::UnitConverter.to_grams(1, "oz"), 0.01
  end

  test "converts pounds" do
    assert_in_delta 453.59, Nutrition::UnitConverter.to_grams(1, "lb"), 0.01
  end

  test "converts lbs (plural)" do
    assert_in_delta 907.18, Nutrition::UnitConverter.to_grams(2, "lbs"), 0.01
  end

  test "returns nil for volume unit" do
    assert_nil Nutrition::UnitConverter.to_grams(1, "cup")
  end

  test "returns nil for universal unit" do
    assert_nil Nutrition::UnitConverter.to_grams(1, "pinch")
  end

  test "returns nil for blank unit" do
    assert_nil Nutrition::UnitConverter.to_grams(1, "")
    assert_nil Nutrition::UnitConverter.to_grams(1, nil)
  end

  test "weight_unit? returns true for weight units" do
    assert Nutrition::UnitConverter.weight_unit?("g")
    assert Nutrition::UnitConverter.weight_unit?("oz")
    assert Nutrition::UnitConverter.weight_unit?("lb")
  end

  test "weight_unit? returns false for non-weight units" do
    assert_not Nutrition::UnitConverter.weight_unit?("cup")
    assert_not Nutrition::UnitConverter.weight_unit?("tbsp")
    assert_not Nutrition::UnitConverter.weight_unit?("large")
  end
end

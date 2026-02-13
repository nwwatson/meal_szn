require "test_helper"

class RecipeInstructionTest < ActiveSupport::TestCase
  test "belongs to recipe" do
    instruction = recipe_instructions(:salmon_step_one)
    assert_equal recipes(:one), instruction.recipe
  end

  test "requires step_number" do
    instruction = RecipeInstruction.new(recipe: recipes(:side_dish), instruction: "Do something")
    assert_not instruction.valid?
    assert_includes instruction.errors[:step_number], "can't be blank"
  end

  test "requires instruction text" do
    instruction = RecipeInstruction.new(recipe: recipes(:side_dish), step_number: 1)
    assert_not instruction.valid?
    assert_includes instruction.errors[:instruction], "can't be blank"
  end

  test "step_number must be positive integer" do
    instruction = RecipeInstruction.new(recipe: recipes(:side_dish), instruction: "Test", step_number: -1)
    assert_not instruction.valid?
    assert_includes instruction.errors[:step_number], "must be greater than 0"
  end

  test "step_number must be unique per recipe" do
    existing = recipe_instructions(:salmon_step_one)
    duplicate = RecipeInstruction.new(
      recipe: existing.recipe,
      step_number: existing.step_number,
      instruction: "Duplicate step"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:step_number], "has already been taken"
  end

  test "same step_number allowed on different recipes" do
    instruction = RecipeInstruction.new(
      recipe: recipes(:side_dish),
      step_number: 1,
      instruction: "Boil cauliflower"
    )
    assert instruction.valid?
  end

  test "default scope orders by step_number" do
    recipe = recipes(:one)
    instructions = recipe.instructions
    assert_equal 1, instructions.first.step_number
    assert_equal 2, instructions.last.step_number
  end

  test "to_api_response returns step_number and instruction" do
    instruction = recipe_instructions(:salmon_step_one)
    response = instruction.to_api_response
    assert_equal 1, response[:step_number]
    assert instruction.instruction.present?
    assert_equal instruction.instruction, response[:instruction]
  end

  test "generates UUID id on create" do
    instruction = RecipeInstruction.create!(
      recipe: recipes(:side_dish),
      step_number: 1,
      instruction: "Test step"
    )
    assert instruction.id.present?
  end
end

require "test_helper"

class AccessTest < ActiveSupport::TestCase
  test "belongs to account" do
    access = accesses(:access_only)
    assert_equal accounts(:one), access.account
  end

  test "belongs to user" do
    access = accesses(:access_only)
    assert_equal users(:one), access.user
  end

  test "belongs to entity (polymorphic)" do
    access = accesses(:access_only)
    assert_equal recipes(:one), access.entity
  end

  test "involvement enum" do
    assert_equal %w[access_only watching], Access.involvements.keys
  end

  test "user_id unique per entity" do
    existing = accesses(:access_only)
    duplicate = Access.new(
      account: existing.account,
      user: existing.user,
      entity: existing.entity,
      involvement: :watching
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "watching scope" do
    watching = Access.watching
    assert_includes watching, accesses(:watching)
    assert_not_includes watching, accesses(:access_only)
  end

  test "for_entity_type scope" do
    recipe_accesses = Access.for_entity_type("Recipe")
    assert_includes recipe_accesses, accesses(:access_only)
    assert_includes recipe_accesses, accesses(:watching)
  end

  test "grant_to creates access for users" do
    user = users(:admin)
    recipe = recipes(:side_dish)

    Access.grant_to([ user ], entity: recipe)

    access = Access.find_by(user: user, entity: recipe)
    assert access.present?
    assert_equal user.account, access.account
  end

  test "grant_to is idempotent" do
    user = users(:one)
    recipe = recipes(:one)

    assert_no_difference "Access.count" do
      Access.grant_to([ user ], entity: recipe)
    end
  end

  test "revoke_from destroys accesses for users" do
    user = users(:one)
    assert Access.where(user: user).exists?

    Access.revoke_from([ user ])

    assert_not Access.where(user: user).exists?
  end

  test "generates UUID id on create" do
    access = Access.create!(
      account: accounts(:one),
      user: users(:admin),
      entity: recipes(:side_dish)
    )
    assert access.id.present?
  end
end

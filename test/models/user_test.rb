require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "belongs to account" do
    user = users(:one)
    assert_respond_to user, :account
    assert_not_nil user.account
  end

  test "can belong to identity" do
    user = users(:one)
    assert_respond_to user, :identity
  end

  test "requires name" do
    user = User.new(account: accounts(:one))
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "generates id on create" do
    user = User.create!(account: accounts(:one), name: "Test User")
    assert user.id.present?
  end

  test "defaults to member role" do
    user = User.create!(account: accounts(:one), name: "Test User")
    assert_equal "member", user.role
  end

  test "role enum includes expected values" do
    assert_equal %w[owner admin member system], User.roles.keys
  end

  test "owner? returns true for owner role" do
    user = User.new(role: :owner)
    assert user.owner?
  end

  test "admin? returns true for admin role" do
    user = User.new(role: :admin)
    assert user.admin?
  end

  test "member? returns true for member role" do
    user = User.new(role: :member)
    assert user.member?
  end

  test "active scope excludes inactive users" do
    account = accounts(:one)
    active_user = User.create!(account: account, name: "Active", active: true)
    inactive_user = User.create!(account: account, name: "Inactive", active: false)

    assert_includes User.active, active_user
    assert_not_includes User.active, inactive_user
  end

  test "defaults to active" do
    user = User.create!(account: accounts(:one), name: "New User")
    assert user.active
  end

  test "has_role_at_least? checks role hierarchy" do
    owner = User.new(role: :owner)
    admin = User.new(role: :admin)
    member = User.new(role: :member)

    # Owner has all roles
    assert owner.has_role_at_least?(:member)
    assert owner.has_role_at_least?(:admin)
    assert owner.has_role_at_least?(:owner)

    # Admin has member and admin roles
    assert admin.has_role_at_least?(:member)
    assert admin.has_role_at_least?(:admin)
    assert_not admin.has_role_at_least?(:owner)

    # Member only has member role
    assert member.has_role_at_least?(:member)
    assert_not member.has_role_at_least?(:admin)
    assert_not member.has_role_at_least?(:owner)
  end

  test "has settings association" do
    user = users(:one)
    assert_respond_to user, :settings
  end

  test "creates settings automatically" do
    user = User.create!(account: accounts(:one), name: "Settings Test")
    user.settings # Trigger creation via association
    assert user.settings.present?
  end
end

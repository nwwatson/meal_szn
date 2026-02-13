require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "generates id on create" do
    account = Account.create!(name: "Test Account")
    assert account.id.present?
  end

  test "generates unique 8-digit external account id" do
    account = Account.create!(name: "Test Account")
    assert account.external_account_id.present?
    assert_match(/\A\d{8}\z/, account.external_account_id.to_s)
  end

  test "requires name" do
    account = Account.new
    assert_not account.valid?
    assert_includes account.errors[:name], "can't be blank"
  end

  test "has many users" do
    account = accounts(:one)
    assert_respond_to account, :users
  end

  test "requires_onboarding? returns true when no accounts exist" do
    Account.destroy_all
    assert Account.requires_onboarding?
  end

  test "requires_onboarding? returns false when accounts exist" do
    assert_not Account.requires_onboarding? if Account.any?
  end

  test "accepting_signups? delegates to multi_tenant setting" do
    assert_respond_to Account, :accepting_signups?
  end

  test "create_with_owner creates account and owner user" do
    identity = identities(:two)

    account = Account.create_with_owner(
      name: "New Organization",
      owner_name: "John Doe",
      owner_identity: identity
    )

    assert account.persisted?
    assert_equal "New Organization", account.name
    assert_equal 2, account.users.count

    owner = account.owner
    assert_equal "John Doe", owner.name
    assert owner.owner?
    assert_equal identity, owner.identity
  end

  test "owner returns the owner user" do
    account = accounts(:one)
    owner = account.owner
    assert owner.owner? if owner.present?
  end

  test "external_account_id is unique" do
    account1 = Account.create!(name: "Account 1")
    account2 = Account.new(name: "Account 2", external_account_id: account1.external_account_id)
    assert_not account2.valid?
    assert_includes account2.errors[:external_account_id], "has already been taken"
  end
end

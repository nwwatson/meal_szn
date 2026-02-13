require "test_helper"

class Account::CancellationTest < ActiveSupport::TestCase
  test "belongs to account" do
    cancellation = Account::Cancellation.create!(account: accounts(:two), user: users(:one))
    assert_equal accounts(:two), cancellation.account
  end

  test "belongs to user" do
    cancellation = Account::Cancellation.create!(account: accounts(:two), user: users(:one))
    assert_equal users(:one), cancellation.user
  end

  test "account_id must be unique" do
    Account::Cancellation.create!(account: accounts(:two), user: users(:one))
    duplicate = Account::Cancellation.new(account: accounts(:two), user: users(:two))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:account_id], "has already been taken"
  end

  test "generates UUID id on create" do
    cancellation = Account::Cancellation.create!(account: accounts(:two), user: users(:one))
    assert cancellation.id.present?
    assert_match(/\A[0-9a-f-]{36}\z/, cancellation.id)
  end
end

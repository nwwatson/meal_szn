require "test_helper"

class Account::JoinCodeTest < ActiveSupport::TestCase
  test "belongs to account" do
    join_code = account_join_codes(:active)
    assert_equal accounts(:one), join_code.account
  end

  test "generates code on create" do
    join_code = Account::JoinCode.create!(account: accounts(:two))
    assert join_code.code.present?
    assert_equal Account::JoinCode::CODE_LENGTH, join_code.code.length
  end

  test "code must be unique" do
    existing = account_join_codes(:active)
    duplicate = Account::JoinCode.new(account: accounts(:two), code: existing.code)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "usage_limit must be positive" do
    join_code = Account::JoinCode.new(account: accounts(:two), usage_limit: 0)
    assert_not join_code.valid?
    assert_includes join_code.errors[:usage_limit], "must be greater than 0"
  end

  test "active? returns true when usage_count below limit" do
    join_code = account_join_codes(:active)
    assert join_code.active?
  end

  test "active? returns false when usage_count reaches limit" do
    join_code = account_join_codes(:near_limit)
    join_code.update_column(:usage_count, join_code.usage_limit)
    assert_not join_code.active?
  end

  test "active scope returns codes with available uses" do
    active_codes = Account::JoinCode.active
    assert_includes active_codes, account_join_codes(:active)
    assert_includes active_codes, account_join_codes(:near_limit)
  end

  test "redeem_if increments usage_count when block returns true" do
    join_code = account_join_codes(:active)
    initial_count = join_code.usage_count

    result = join_code.redeem_if { true }

    assert result
    assert_equal initial_count + 1, join_code.reload.usage_count
  end

  test "redeem_if does not increment when block returns false" do
    join_code = account_join_codes(:active)
    initial_count = join_code.usage_count

    result = join_code.redeem_if { false }

    assert_not result
    assert_equal initial_count, join_code.reload.usage_count
  end

  test "redeem_if returns false when not active" do
    join_code = account_join_codes(:near_limit)
    join_code.update_column(:usage_count, join_code.usage_limit)

    result = join_code.redeem_if { true }
    assert_not result
  end

  test "reset regenerates code and resets usage_count" do
    join_code = account_join_codes(:near_limit)
    old_code = join_code.code

    join_code.reset

    assert_not_equal old_code, join_code.code
    assert_equal 0, join_code.usage_count
  end

  test "formatted_code groups in chunks of 4" do
    join_code = account_join_codes(:active)
    # Code is "ABC123DEF456" → "ABC1-23DE-F456"
    formatted = join_code.formatted_code
    assert_match(/\A.{4}-.{4}-.{4}\z/, formatted)
  end

  test "generates UUID id on create" do
    join_code = Account::JoinCode.create!(account: accounts(:two))
    assert join_code.id.present?
  end
end

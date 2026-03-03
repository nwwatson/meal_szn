require "test_helper"

class PendingRecipeTransferTest < ActiveSupport::TestCase
  test "generates id on create" do
    transfer = PendingRecipeTransfer.create!(
      identity: identities(:one),
      source_recipe: recipes(:two)
    )
    assert transfer.id.present?
  end

  test "validates uniqueness of source_recipe per identity" do
    # The fixture already has identity two + recipe one
    existing = pending_recipe_transfers(:transfer_salmon)
    transfer = PendingRecipeTransfer.new(
      identity_id: existing.identity_id,
      source_recipe_id: existing.source_recipe_id
    )
    assert_not transfer.valid?
  end

  test "execute_for forks recipes into target account and cleans up" do
    identity = identities(:two)
    target_account = accounts(:two)

    assert PendingRecipeTransfer.where(identity_id: identity.id).exists?

    forked = PendingRecipeTransfer.execute_for(identity, target_account)

    assert_equal 1, forked.length
    assert_equal target_account, forked.first.account
    assert_equal recipes(:one).title, forked.first.title
    assert_equal 0, PendingRecipeTransfer.where(identity_id: identity.id).count
  end

  test "execute_for returns empty array when no transfers" do
    identity = identities(:staff)
    result = PendingRecipeTransfer.execute_for(identity, accounts(:two))
    assert_equal [], result
  end
end

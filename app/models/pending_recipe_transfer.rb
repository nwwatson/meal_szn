class PendingRecipeTransfer < ApplicationRecord
  belongs_to :identity
  belongs_to :source_recipe, class_name: "Recipe"

  validates :source_recipe_id, uniqueness: { scope: :identity_id }

  before_create :generate_id

  def self.execute_for(identity, target_account)
    transfers = where(identity: identity)
    return [] if transfers.none?

    forked_recipes = transfers.includes(source_recipe: [ :ingredients, :instructions, :nutrition_data, :tips, :tags ]).map do |transfer|
      RecipeFork.call(transfer.source_recipe, target_account)
    end

    transfers.delete_all
    forked_recipes.compact
  end

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end
end

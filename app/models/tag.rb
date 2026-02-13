class Tag < ApplicationRecord
  include Identifiable

  belongs_to :account
  has_many :recipe_tags, dependent: :destroy
  has_many :recipes, through: :recipe_tags

  validates :name, presence: true, uniqueness: { scope: :account_id, case_sensitive: false }

  before_validation :normalize_name

  scope :alphabetical, -> { order(:name) }
  scope :with_recipe_count, -> { left_joins(:recipe_tags).group(:id).select("tags.*, COUNT(recipe_tags.id) AS recipe_count") }

  private

  def normalize_name
    self.name = name.strip.downcase if name.present?
  end
end

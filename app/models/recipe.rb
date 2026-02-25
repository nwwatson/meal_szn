class Recipe < ApplicationRecord
  include Identifiable

  belongs_to :account
  has_one_attached :image
  has_many :ingredients, -> { order(:display_order) }, dependent: :destroy
  has_many :instructions, class_name: "RecipeInstruction", dependent: :destroy
  has_one :nutrition_data, class_name: "RecipeNutritionData", dependent: :destroy
  has_many :tips, class_name: "RecipeTip", dependent: :destroy
  has_many :recipe_tags, dependent: :destroy
  has_many :tags, through: :recipe_tags

  validates :title, presence: true
  validates :category, presence: true

  enum :category, {
    breakfast: 0,
    lunch: 1,
    dinner: 2,
    sides: 3,
    snacks: 4,
    sauces: 5
  }

  accepts_nested_attributes_for :ingredients, allow_destroy: true
  accepts_nested_attributes_for :instructions, allow_destroy: true
  accepts_nested_attributes_for :nutrition_data, allow_destroy: true
  accepts_nested_attributes_for :tips, allow_destroy: true

  scope :by_category, ->(category) { where(category: category) if category.present? }
  scope :by_tags, ->(tag_ids) { joins(:recipe_tags).where(recipe_tags: { tag_id: tag_ids }).distinct if tag_ids.present? }

  def unresolved_ingredients
    ingredients.where(nutrition_item_id: nil)
  end

  def all_ingredients_resolved?
    ingredients.none? || ingredients.where(nutrition_item_id: nil).none?
  end

  def total_time
    (prep_time || 0) + (cook_time || 0)
  end

  def ingredients_summary
    ingredients.limit(5).pluck(:name).join(", ")
  end

  def tag_list
    tags.pluck(:name).join(", ")
  end

  def sync_tags_from_list(names_string, account)
    return self.tags = [] if names_string.blank?

    tag_names = names_string.split(",").map { |n| n.strip.downcase }.reject(&:blank?).uniq
    new_tags = tag_names.map { |name| account.tags.find_or_create_by!(name: name) }
    self.tags = new_tags
  end

  def to_api_response
    {
      id: id,
      title: title,
      category: category,
      description: description,
      source: source,
      servings: servings,
      prep_time: prep_time,
      cook_time: cook_time,
      total_time: total_time,
      ingredients: ingredients.map(&:to_api_response),
      instructions: instructions.order(:step_number).map(&:to_api_response),
      nutrition: nutrition_data&.to_api_response,
      tags: tags.pluck(:name),
      tips: tips.map(&:tip),
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def to_meal_planning_response
    {
      id: id,
      title: title,
      category: category,
      servings: servings,
      prep_time: prep_time,
      cook_time: cook_time,
      nutrition_per_serving: nutrition_data&.to_meal_planning_response,
      tags: tags.pluck(:name),
      ingredients_summary: ingredients_summary,
      url: "/#{account.external_account_id}/recipes/#{id}"
    }
  end
end

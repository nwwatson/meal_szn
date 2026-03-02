class Recipe < ApplicationRecord
  include Identifiable

  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
  MAX_IMAGE_SIZE = 10.megabytes

  belongs_to :account
  has_one_attached :image do |attachable|
    attachable.variant :thumbnail, resize_to_fill: [ 200, 200 ]
    attachable.variant :card, resize_to_fill: [ 400, 300 ]
    attachable.variant :full, resize_to_fill: [ 1200, 800 ]
  end
  has_many_attached :images
  has_many :ingredients, -> { order(:display_order) }, dependent: :destroy
  has_many :instructions, class_name: "RecipeInstruction", dependent: :destroy
  has_one :nutrition_data, class_name: "RecipeNutritionData", dependent: :destroy
  has_many :tips, class_name: "RecipeTip", dependent: :destroy
  has_many :recipe_tags, dependent: :destroy
  has_many :tags, through: :recipe_tags
  has_many :meal_plan_meals

  validates :title, presence: true
  validates :category, presence: true
  validates :rating, inclusion: { in: 1..5 }, allow_nil: true
  validate :validate_image_attachment
  validate :validate_images_attachments

  after_commit :enqueue_nutrition_calculation, on: [ :create, :update ], if: :should_auto_calculate_nutrition?

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
  scope :by_diet, ->(diet_slug) {
    joins(:tags).where(tags: { name: "#{DietCategorizer::TAG_PREFIX}#{diet_slug}" }).distinct if diet_slug.present?
  }
  scope :by_search, ->(query) {
    if query.present?
      sanitized = "%#{sanitize_sql_like(query)}%"
      left_joins(:ingredients)
        .where("recipes.title LIKE :q OR recipes.description LIKE :q OR ingredients.name LIKE :q", q: sanitized)
        .group("recipes.id")
    end
  }
  scope :by_cook_time, ->(max_minutes) {
    where("COALESCE(prep_time, 0) + COALESCE(cook_time, 0) <= ?", max_minutes.to_i) if max_minutes.present?
  }
  scope :by_min_rating, ->(min) { where("rating >= ?", min.to_i) if min.present? }
  scope :by_calorie_range, ->(min_cal, max_cal) {
    if min_cal.present? || max_cal.present?
      scope = joins(:nutrition_data)
      scope = scope.where("recipe_nutrition_data.calories >= ?", min_cal.to_i) if min_cal.present?
      scope = scope.where("recipe_nutrition_data.calories <= ?", max_cal.to_i) if max_cal.present?
      scope
    end
  }
  scope :sorted_by, ->(sort) {
    case sort.to_s
    when "alphabetical"
      order(title: :asc)
    when "quickest"
      order(Arel.sql("COALESCE(prep_time, 0) + COALESCE(cook_time, 0) ASC"))
    when "most_used"
      left_joins(:meal_plan_meals).group("recipes.id").order(Arel.sql("COUNT(DISTINCT meal_plan_meals.id) DESC"))
    when "highest_rated"
      order(Arel.sql("COALESCE(rating, 3) DESC, created_at DESC"))
    else
      order(created_at: :desc)
    end
  }

  def categorize_diets!
    DietCategorizer.new(self).categorize!
  end

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
      rating: rating,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def to_meal_planning_response
    Rails.cache.fetch("#{cache_key_with_version}/meal_planning_response") do
      {
        id: id,
        title: title,
        category: category,
        servings: servings,
        prep_time: prep_time,
        cook_time: cook_time,
        nutrition_per_serving: nutrition_data&.to_meal_planning_response,
        tags: tags.pluck(:name),
        rating: rating
      }
    end
  end

  private

  def enqueue_nutrition_calculation
    NutritionCalculationJob.perform_later(id)
  end

  def should_auto_calculate_nutrition?
    # Skip if nutrition was manually provided or no ingredients exist
    return false if ingredients.none?
    return false if nutrition_data.present? && !nutrition_data.auto_calculated?
    true
  end

  def validate_image_attachment
    validate_single_image(image, :image) if image.attached?
  end

  def validate_images_attachments
    return unless images.attached?

    images.each do |img|
      validate_single_image(img, :images)
    end
  end

  def validate_single_image(img, attribute)
    unless img.blob.content_type.in?(ALLOWED_IMAGE_TYPES)
      errors.add(attribute, "must be a JPEG, PNG, WebP, or GIF file")
    end

    if img.blob.byte_size > MAX_IMAGE_SIZE
      errors.add(attribute, "must be less than 10MB")
    end
  end
end

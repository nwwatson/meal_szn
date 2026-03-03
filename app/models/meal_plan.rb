class MealPlan < ApplicationRecord
  include Identifiable

  belongs_to :account
  belongs_to :user
  has_many :days, class_name: "MealPlanDay", dependent: :destroy
  has_many :participants, class_name: "MealPlanParticipant", dependent: :destroy
  has_many :dietary_profiles, through: :participants
  has_many :shopping_lists, dependent: :destroy

  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date

  accepts_nested_attributes_for :days, allow_destroy: true

  scope :current, -> { where("start_date <= ? AND end_date >= ?", Date.current, Date.current) }
  scope :upcoming, -> { where("start_date > ?", Date.current) }
  scope :past, -> { where("end_date < ?", Date.current) }
  scope :recent, -> { order(start_date: :desc) }

  def current?
    start_date <= Date.current && end_date >= Date.current
  end

  def duration_days
    (end_date - start_date).to_i + 1
  end

  def total_calories
    days.sum do |day|
      day.meals.sum { |meal| meal.recipe.nutrition_data&.calories.to_i * meal.servings }
    end
  end

  def average_daily_calories
    return 0 if days.empty?
    total_calories / days.count
  end

  def to_api_summary
    {
      id: id,
      name: name,
      start_date: start_date,
      end_date: end_date,
      duration_days: duration_days,
      daily_calories_target: daily_calories_target,
      average_daily_calories: average_daily_calories.round
    }
  end

  def to_api_response
    {
      id: id,
      name: name,
      start_date: start_date,
      end_date: end_date,
      duration_days: duration_days,
      daily_calories_target: daily_calories_target,
      average_daily_calories: average_daily_calories.round,
      days: days.includes(meals: { recipe: :nutrition_data }).order(:day_number).map(&:to_api_response),
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date
    if end_date < start_date
      errors.add(:end_date, "must be after start date")
    end
  end
end

class RecipeTip < ApplicationRecord
  include Identifiable

  belongs_to :recipe, touch: true

  validates :tip, presence: true
end

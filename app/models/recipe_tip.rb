class RecipeTip < ApplicationRecord
  include Identifiable

  belongs_to :recipe

  validates :tip, presence: true
end

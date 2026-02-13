module Identifiable
  extend ActiveSupport::Concern

  included do
    before_create :generate_id
  end

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end
end

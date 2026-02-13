module User::Accessor
  extend ActiveSupport::Concern

  included do
    has_many :accesses, dependent: :destroy
  end

  # Grant access to a specific entity
  def grant_access_to(entity, involvement: :access_only)
    accesses.find_or_create_by!(account: account, entity: entity) do |access|
      access.involvement = involvement
    end
  end

  # Revoke access from a specific entity
  def revoke_access_from(entity)
    accesses.find_by(entity: entity)&.destroy
  end

  # Check if user has access to a specific entity
  def has_access_to?(entity)
    accesses.exists?(entity: entity)
  end
end

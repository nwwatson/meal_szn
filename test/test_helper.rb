ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    set_fixture_class recipe_nutrition_data: RecipeNutritionData
    set_fixture_class account_join_codes: Account::JoinCode
    set_fixture_class account_cancellations: Account::Cancellation
    set_fixture_class user_settings: User::Settings
    set_fixture_class nutrition_item_aliases: NutritionItem::Alias
    set_fixture_class nutrition_item_portions: NutritionItem::Portion
    set_fixture_class shopping_list_items: ShoppingListItem
    set_fixture_class meal_plan_meal_portions: MealPlanMealPortion
  end
end

module SignInHelper
  # Sets a properly signed session cookie for integration tests.
  # Replicates the exact signing flow Rails uses internally:
  #   1. JSON-serialize the value (SerializedCookieJars#commit)
  #   2. Sign with MessageVerifier using NullSerializer + purpose metadata
  def sign_in_as(session_or_identity)
    session = session_or_identity.is_a?(Session) ? session_or_identity : session_or_identity.sessions.first
    signed_id = session.signed_id

    serialized = ActiveSupport::Messages::SerializerWithFallback[:json].dump(signed_id)

    secret = Rails.application.key_generator.generate_key("signed cookie")
    verifier = ActiveSupport::MessageVerifier.new(secret, digest: "SHA1", serializer: ActiveSupport::MessageEncryptor::NullSerializer)
    cookies[:session_token] = verifier.generate(serialized, purpose: "cookie.session_token")
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper
end

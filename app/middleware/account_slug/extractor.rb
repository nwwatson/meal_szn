module AccountSlug
end

class AccountSlug::Extractor
  ACCOUNT_ID_PATTERN = /\A\/(\d{8})(\/.*)?/.freeze
  EXCLUDED_PATHS = %w[
    /session
    /signup
    /onboarding
    /identity
    /rails
    /assets
    /up
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    path = request.path_info

    return @app.call(env) if excluded_path?(path)

    if (match = path.match(ACCOUNT_ID_PATTERN))
      external_account_id = match[1]
      remaining_path = match[2] || "/"

      if (account = Account.find_by(external_account_id: external_account_id))
        env["meal_szn.account"] = account
        env["meal_szn.original_path"] = path
        env["PATH_INFO"] = remaining_path
        env["SCRIPT_NAME"] = "/#{external_account_id}"
      end
    end

    @app.call(env)
  end

  private

  def excluded_path?(path)
    EXCLUDED_PATHS.any? { |prefix| path.start_with?(prefix) }
  end
end

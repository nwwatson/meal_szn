# Require the middleware class
require_relative "../../app/middleware/account_slug/extractor"

# Insert the middleware into the stack
Rails.application.config.middleware.use AccountSlug::Extractor

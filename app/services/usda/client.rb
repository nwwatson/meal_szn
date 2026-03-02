require "net/http"
require "json"

module Usda
  class Client
    BASE_URL = "https://api.nal.usda.gov"

    class ApiError < StandardError; end
    class RateLimitError < ApiError; end

    def initialize(api_key: nil)
      @api_key = api_key || Rails.application.credentials.usda_api_key
    end

    CACHE_TTL = 24.hours

    def search(query, page_size: 10)
      cache_key = "usda:search:#{Digest::SHA256.hexdigest("#{query}:#{page_size}")}"

      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        params = {
          query: query,
          dataType: "SR Legacy,Foundation",
          pageSize: page_size,
          api_key: @api_key
        }

        get("/fdc/v1/foods/search", params)
      end
    end

    def food(fdc_id)
      cache_key = "usda:food:#{fdc_id}"

      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        get("/fdc/v1/food/#{fdc_id}", api_key: @api_key)
      end
    end

    private

    def get(path, params = {})
      uri = URI("#{BASE_URL}#{path}")
      uri.query = URI.encode_www_form(params)

      response = Net::HTTP.get_response(uri)

      case response
      when Net::HTTPSuccess
        JSON.parse(response.body)
      when Net::HTTPTooManyRequests
        raise RateLimitError, "USDA API rate limit exceeded"
      else
        raise ApiError, "USDA API error: #{response.code} #{response.message}"
      end
    end
  end
end

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

    def search(query, page_size: 10)
      params = {
        query: query,
        dataType: "SR Legacy,Foundation",
        pageSize: page_size,
        api_key: @api_key
      }

      get("/fdc/v1/foods/search", params)
    end

    def food(fdc_id)
      get("/fdc/v1/food/#{fdc_id}", api_key: @api_key)
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

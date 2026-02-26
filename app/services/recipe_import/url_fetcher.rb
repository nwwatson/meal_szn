# frozen_string_literal: true

require "net/http"

module RecipeImport
  class UrlFetcher
    class FetchError < StandardError; end

    MAX_REDIRECTS = 5
    TIMEOUT = 15
    USER_AGENT = "MealSzn/1.0 RecipeImporter"

    def initialize(url)
      @url = url
    end

    def fetch
      uri = validated_uri
      follow_redirects(uri)
    rescue URI::InvalidURIError => e
      raise FetchError, "Invalid URL: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise FetchError, "Request timed out"
    rescue SocketError, Errno::ECONNREFUSED => e
      raise FetchError, "Could not connect: #{e.message}"
    rescue OpenSSL::SSL::SSLError => e
      raise FetchError, "SSL error: #{e.message}"
    end

    private

    def validated_uri
      uri = URI.parse(@url)
      raise URI::InvalidURIError, "URL must use http or https" unless %w[http https].include?(uri.scheme)
      uri
    end

    def follow_redirects(uri, limit = MAX_REDIRECTS)
      raise FetchError, "Too many redirects" if limit == 0

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT
      request["Accept"] = "text/html"

      response = http.request(request)

      case response
      when Net::HTTPSuccess
        response.body.force_encoding("UTF-8")
      when Net::HTTPRedirection
        location = response["location"]
        new_uri = URI.parse(location)
        new_uri = URI.join(uri, location) unless new_uri.host
        follow_redirects(new_uri, limit - 1)
      else
        raise FetchError, "HTTP #{response.code}: #{response.message}"
      end
    end
  end
end

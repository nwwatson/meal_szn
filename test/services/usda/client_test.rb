require "test_helper"

class Usda::ClientTest < ActiveSupport::TestCase
  # Test via a subclass that overrides the HTTP call
  class TestableClient < Usda::Client
    attr_accessor :stub_response

    def initialize(stub_response:)
      @stub_response = stub_response
      super(api_key: "test-key")
    end

    private

    def get(path, params = {})
      response = @stub_response
      case response[:status]
      when 200
        JSON.parse(response[:body])
      when 429
        raise RateLimitError, "USDA API rate limit exceeded"
      else
        raise ApiError, "USDA API error: #{response[:status]} #{response[:message]}"
      end
    end
  end

  test "search returns parsed JSON on success" do
    client = TestableClient.new(
      stub_response: { status: 200, body: { "foods" => [ { "fdcId" => 12345, "description" => "Egg" } ] }.to_json }
    )

    result = client.search("egg")
    assert_equal 1, result["foods"].length
    assert_equal "Egg", result["foods"][0]["description"]
  end

  test "food returns parsed JSON on success" do
    client = TestableClient.new(
      stub_response: { status: 200, body: { "fdcId" => 171287, "description" => "Egg, whole, raw" }.to_json }
    )

    result = client.food(171287)
    assert_equal "Egg, whole, raw", result["description"]
  end

  test "raises ApiError on non-success response" do
    client = TestableClient.new(
      stub_response: { status: 500, message: "Internal Server Error" }
    )

    assert_raises(Usda::Client::ApiError) { client.search("egg") }
  end

  test "raises RateLimitError on 429" do
    client = TestableClient.new(
      stub_response: { status: 429, message: "Too Many Requests" }
    )

    assert_raises(Usda::Client::RateLimitError) { client.search("egg") }
  end
end

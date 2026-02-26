# frozen_string_literal: true

module RecipeImport
  class UrlImporter
    class ImportError < StandardError; end

    attr_reader :url, :method_used

    def initialize(url, ai_client: nil)
      @url = url
      @ai_client = ai_client
      @method_used = nil
    end

    def import
      html = fetch_html
      recipe_data = try_json_ld(html) || try_ai_extraction(html)

      raise ImportError, "Could not extract recipe data from this URL" unless recipe_data
      raise ImportError, "No recipe title found" if recipe_data[:title].blank?

      recipe_data[:source] = @url
      recipe_data
    rescue UrlFetcher::FetchError => e
      raise ImportError, "Failed to fetch URL: #{e.message}"
    end

    private

    def fetch_html
      UrlFetcher.new(@url).fetch
    end

    def try_json_ld(html)
      result = JsonLdParser.new(html).parse
      if result && result[:title].present?
        @method_used = :json_ld
        result
      end
    end

    def try_ai_extraction(html)
      # Strip HTML to plain text for AI
      text = extract_text(html)
      return nil if text.blank?

      result = AiExtractor.new(text, ai_client: @ai_client).extract
      if result && result[:title].present?
        @method_used = :ai
        result
      end
    rescue Ai::Client::Error
      nil
    end

    def extract_text(html)
      doc = Nokogiri::HTML(html)
      doc.css("script, style, nav, header, footer, aside").remove
      doc.text.gsub(/\s+/, " ").strip[0, 15_000]
    end
  end
end

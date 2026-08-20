# Google's Gemini API has a real, ongoing free tier (rate-limited, not a one-time
# trial) -- the last resort in AnalyzerService.free_analyzer's chain, tried after
# OpenRouter's free models.
module Analyzers
  class GeminiAnalyzer < BaseAnalyzer
    DEFAULT_MODEL = "gemini-1.5-flash"

    def self.key_label = "Gemini"
    def self.api_key_env_var = "GEMINI_API_KEY"

    def initialize(model: DEFAULT_MODEL, api_key: nil)
      @model = model
      super(api_key: api_key)
    end

    def label = "Gemini (#{@model})"

    private

    def request(prompt)
      Faraday.post(
        "https://generativelanguage.googleapis.com/v1beta/models/#{@model}:generateContent?key=#{@api_key}",
        { contents: [ { parts: [ { text: prompt } ] } ] }.to_json,
        { "Content-Type" => "application/json" }
      )
    end

    def extract_text(body)
      JSON.parse(body).dig("candidates", 0, "content", "parts", 0, "text")
    end
  end
end

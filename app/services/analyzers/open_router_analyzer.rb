# OpenRouter (https://openrouter.ai) fronts many models behind one OpenAI-compatible
# API -- only the models tagged `:free` in their catalog cost nothing. One instance of
# this class talks to one specific model; see AnalyzerService.free_analyzer for
# chaining several free models together via FallbackAnalyzer.
module Analyzers
  class OpenRouterAnalyzer < BaseAnalyzer
    def self.key_label = "OpenRouter"
    def self.api_key_env_var = "OPENROUTER_API_KEY"

    def initialize(model:, api_key: nil)
      @model = model
      super(api_key: api_key)
    end

    def label = "OpenRouter (#{@model})"

    private

    def request(prompt)
      Faraday.post(
        "https://openrouter.ai/api/v1/chat/completions",
        { model: @model, messages: [ { role: "user", content: prompt } ] }.to_json,
        { "Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json" }
      )
    end

    def extract_text(body)
      JSON.parse(body).dig("choices", 0, "message", "content")
    end
  end
end

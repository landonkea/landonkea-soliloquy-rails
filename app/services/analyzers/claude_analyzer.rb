# Calls Anthropic's Claude API -- the paid option in the analysis chain. Only used when
# $ANALYZER_PROVIDER=claude is set explicitly (see AnalyzerService.default), matching
# the original's "free by default, Claude opt-in" design.
module Analyzers
  class ClaudeAnalyzer < BaseAnalyzer
    MODEL = "claude-sonnet-5"
    API_VERSION = "2023-06-01"

    # The service/env-var pairing is "Anthropic" (matches ANTHROPIC_API_KEY), but the
    # model/product itself is "Claude" -- used in every other message below, same
    # split the original kept.
    def self.key_label = "Anthropic"
    def self.api_key_env_var = "ANTHROPIC_API_KEY"

    def label = "Claude"

    private

    def request(prompt)
      Faraday.post(
        "https://api.anthropic.com/v1/messages",
        {
          model: MODEL,
          max_tokens: 1024,
          messages: [ { role: "user", content: prompt } ]
        }.to_json,
        {
          "x-api-key" => @api_key,
          "anthropic-version" => API_VERSION,
          "content-type" => "application/json"
        }
      )
    end

    def extract_text(body)
      JSON.parse(body).dig("content", 0, "text")
    end
  end
end

require "test_helper"

class GeminiAnalyzerTest < ActiveSupport::TestCase
  test "parses Gemini's generateContent response shape" do
    stub_request(:post, /generativelanguage\.googleapis\.com/).to_return(
      status: 200,
      body: {
        candidates: [ { content: { parts: [ { text: '{"summary": "s", "mood_notes": "m", "key_topics": []}' } ] } } ]
      }.to_json
    )

    result = Analyzers::GeminiAnalyzer.new(api_key: "fake").analyze([ entries(:one) ])
    assert_equal "s", result.summary
  end
end

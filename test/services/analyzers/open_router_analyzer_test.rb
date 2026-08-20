require "test_helper"

class OpenRouterAnalyzerTest < ActiveSupport::TestCase
  test "parses OpenAI-compatible chat completion responses" do
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions").to_return(
      status: 200,
      body: {
        choices: [ { message: { content: '{"summary": "s", "mood_notes": "m", "key_topics": ["a"]}' } } ]
      }.to_json
    )

    result = Analyzers::OpenRouterAnalyzer.new(model: "some/model:free", api_key: "fake").analyze([ entries(:one) ])
    assert_equal "s", result.summary
    assert_equal [ "a" ], result.key_topics
  end

  test "label includes the model name" do
    analyzer = Analyzers::OpenRouterAnalyzer.new(model: "some/model:free", api_key: "fake")
    assert_equal "OpenRouter (some/model:free)", analyzer.send(:label)
  end
end

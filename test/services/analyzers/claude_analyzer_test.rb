require "test_helper"

class ClaudeAnalyzerTest < ActiveSupport::TestCase
  setup { @entries = [ entries(:one), entries(:two) ] }

  test "raises when no API key is configured" do
    with_env(ANTHROPIC_API_KEY: nil) do
      error = assert_raises(RuntimeError) { Analyzers::ClaudeAnalyzer.new.analyze(@entries) }
      assert_match(/No Anthropic API key found/, error.message)
    end
  end

  test "raises NoEntriesError for an empty entry list" do
    assert_raises(Analyzers::NoEntriesError) { Analyzers::ClaudeAnalyzer.new(api_key: "fake").analyze([]) }
  end

  test "parses a real JSON response into an AnalysisResult" do
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
      status: 200,
      body: {
        content: [ { text: '{"summary": "a summary", "mood_notes": "steady", "mood_score": 7, "key_topics": ["work"]}' } ]
      }.to_json
    )

    result = Analyzers::ClaudeAnalyzer.new(api_key: "fake").analyze(@entries)
    assert_equal "a summary", result.summary
    assert_equal "steady", result.mood_notes
    assert_equal 7, result.mood_score
    assert_equal [ "work" ], result.key_topics
    assert_equal 2, result.entry_count
  end

  test "strips a markdown code fence before parsing" do
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
      status: 200,
      body: { content: [ { text: "```json\n{\"summary\": \"s\", \"mood_notes\": \"m\", \"key_topics\": []}\n```" } ] }.to_json
    )

    result = Analyzers::ClaudeAnalyzer.new(api_key: "fake").analyze(@entries)
    assert_equal "s", result.summary
    assert_nil result.mood_score
  end

  test "raises RateLimitError on a 429" do
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(status: 429, body: "slow down")
    assert_raises(Analyzers::RateLimitError) { Analyzers::ClaudeAnalyzer.new(api_key: "fake").analyze(@entries) }
  end

  test "raises when the response is missing a required key" do
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
      status: 200, body: { content: [ { text: '{"summary": "s"}' } ] }.to_json
    )
    assert_raises(RuntimeError) { Analyzers::ClaudeAnalyzer.new(api_key: "fake").analyze(@entries) }
  end
end

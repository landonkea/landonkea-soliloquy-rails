require "test_helper"

class FallbackAnalyzerTest < ActiveSupport::TestCase
  setup { @entries = [ entries(:one) ] }

  test "moves on to the next provider when the first fails" do
    failing = Minitest::Mock.new
    failing.expect(:analyze, nil) { raise "boom" }
    succeeding_result = AnalysisResult.new(entry_count: 1, total_word_count: 5, summary: "ok", mood_notes: "fine", key_topics: [])
    succeeding = Minitest::Mock.new
    succeeding.expect(:analyze, succeeding_result, [ @entries ], instruction: "")

    result = Analyzers::FallbackAnalyzer.new([ failing, succeeding ]).analyze(@entries)
    assert_equal succeeding_result, result
    failing.verify
    succeeding.verify
  end

  test "raises listing every provider's error once all providers fail" do
    provider = Minitest::Mock.new
    def provider.analyze(*, **) = raise "always fails"
    def provider.class = Struct.new(:name).new("StubProvider")

    error = assert_raises(RuntimeError) { Analyzers::FallbackAnalyzer.new([ provider ]).analyze(@entries) }
    assert_match(/StubProvider: always fails/, error.message)
  end

  test "raises NoEntriesError immediately for an empty entry list, without trying any provider" do
    provider = Minitest::Mock.new # no expectations set -- verify below proves it was never called
    assert_raises(Analyzers::NoEntriesError) { Analyzers::FallbackAnalyzer.new([ provider ]).analyze([]) }
    provider.verify
  end

  test "requires at least one provider" do
    assert_raises(ArgumentError) { Analyzers::FallbackAnalyzer.new([]) }
  end
end

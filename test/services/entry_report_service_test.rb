require "test_helper"

class EntryReportServiceTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "analyze_range hands every entry in the window to the analyzer, unfiltered" do
    fake_result = AnalysisResult.new(entry_count: 2, total_word_count: 1, summary: "s", mood_notes: "m", key_topics: [])
    analyzer = Minitest::Mock.new
    analyzer.expect(:analyze, fake_result) { |entries| entries.size == 2 }

    result = EntryReportService.analyze_range(user: @user, analyzer: analyzer, days: 7)
    assert_equal fake_result, result
    analyzer.verify
  end

  test "report_range for the partner audience only includes partner-shareable entries" do
    fake_result = AnalysisResult.new(entry_count: 1, total_word_count: 1, summary: "s", mood_notes: "m", key_topics: [])
    analyzer = Minitest::Mock.new
    analyzer.expect(
      :analyze, fake_result,
      [ [ entries(:two) ] ], instruction: AnalyzerService::AUDIENCE_INSTRUCTIONS["partner"]
    )

    _result, filtered_entries = EntryReportService.report_range(user: @user, analyzer: analyzer, days: 7, audience: "partner")
    assert_equal [ entries(:two) ], filtered_entries
  end

  test "report_range raises for an unknown audience" do
    assert_raises(ArgumentError) do
      EntryReportService.report_range(user: @user, analyzer: Minitest::Mock.new, days: 7, audience: "stranger")
    end
  end

  test "journaling_streak counts distinct days journaled in the window" do
    days_journaled, window = EntryReportService.journaling_streak(user: @user, window_days: 7)
    assert_equal 7, window
    assert_equal 2, days_journaled # fixtures :one and :two were created on two different days
  end

  test "on_this_day finds entries from the same month/day in an earlier year" do
    old_entry = @user.entries.create!(transcript: "a year ago today", created_at: 1.year.ago)
    found = EntryReportService.on_this_day(user: @user, today: Date.current)
    assert_includes found, old_entry
  end
end

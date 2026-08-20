require "test_helper"

class AnalysisSnapshotTest < ActiveSupport::TestCase
  test "recent orders newest first" do
    newer = users(:one).analysis_snapshots.create!(
      days: 1, audience: "self", entry_count: 1, total_word_count: 5,
      summary: "s", mood_notes: "m", key_topics: [], mood_score: 5, created_at: 1.minute.from_now
    )
    ordered = users(:one).analysis_snapshots.recent
    assert_equal newer, ordered.first
  end

  test "scored excludes snapshots with no mood_score" do
    unscored = users(:one).analysis_snapshots.create!(
      days: 1, audience: "self", entry_count: 1, total_word_count: 5,
      summary: "s", mood_notes: "m", key_topics: [], mood_score: nil
    )
    assert_not_includes AnalysisSnapshot.scored, unscored
    assert_includes AnalysisSnapshot.scored, analysis_snapshots(:one)
  end
end

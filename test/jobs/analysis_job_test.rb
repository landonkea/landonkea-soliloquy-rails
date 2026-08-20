require "test_helper"

class AnalysisJobTest < ActiveJob::TestCase
  test "saves a fresh AnalysisSnapshot for a user with entries" do
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions").to_return(
      status: 200,
      body: { choices: [ { message: { content: '{"summary": "s", "mood_notes": "m", "mood_score": 6, "key_topics": ["work"]}' } } ] }.to_json
    )

    with_env(OPENROUTER_API_KEY: "fake-key") do
      assert_difference("users(:one).analysis_snapshots.count", 1) do
        AnalysisJob.perform_now(days: 7)
      end
    end

    snapshot = users(:one).analysis_snapshots.order(:created_at).last
    assert_equal "s", snapshot.summary
    assert_equal 6, snapshot.mood_score
  end

  test "quietly skips a user with no entries in the window rather than raising" do
    users(:one).entries.destroy_all
    users(:two).entries.destroy_all

    assert_nothing_raised { AnalysisJob.perform_now(days: 1) }
  end
end

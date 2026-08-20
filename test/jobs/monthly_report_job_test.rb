require "test_helper"

class MonthlyReportJobTest < ActiveJob::TestCase
  test "saves a 30-day scheduled report for a user with entries" do
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions").to_return(
      status: 200,
      body: { choices: [ { message: { content: '{"summary": "monthly summary", "mood_notes": "m", "key_topics": []}' } } ] }.to_json
    )

    with_env(OPENROUTER_API_KEY: "fake-key") do
      assert_difference("users(:one).saved_reports.count", 1) do
        MonthlyReportJob.perform_now
      end
    end

    report = users(:one).saved_reports.order(:created_at).last
    assert_equal "scheduled", report.source
    assert_equal 30, report.days
    assert_match(/monthly summary/, report.content)
  end
end

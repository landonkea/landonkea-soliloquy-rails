require "test_helper"

class SavedReportsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "index lists saved reports" do
    get reports_saved_path
    assert_response :success
    assert_match saved_reports(:one).source, response.body
  end

  test "create generates and saves a new report" do
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions").to_return(
      status: 200,
      body: { choices: [ { message: { content: '{"summary": "s", "mood_notes": "m", "key_topics": []}' } } ] }.to_json
    )

    with_env(OPENROUTER_API_KEY: "fake-key") do
      assert_difference("users(:one).saved_reports.count", 1) do
        post reports_saved_path, params: { days: 30, audience: "self" }
      end
    end
    assert_redirected_to reports_saved_path
  end

  test "share_link generates a usable share link" do
    report = saved_reports(:one)
    post saved_report_share_link_path(report), params: { expires_in_days: 7 }
    assert_redirected_to reports_saved_path
    follow_redirect!
    assert_match(%r{/reports/shared/}, response.body)
  end
end

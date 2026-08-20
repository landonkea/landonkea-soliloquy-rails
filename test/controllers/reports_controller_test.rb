require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "new renders the report form" do
    get report_path
    assert_response :success
  end

  test "create streams a downloadable text report" do
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions").to_return(
      status: 200,
      body: { choices: [ { message: { content: '{"summary": "s", "mood_notes": "m", "key_topics": []}' } } ] }.to_json
    )

    with_env(OPENROUTER_API_KEY: "fake-key") do
      post report_path, params: { days: 30, audience: "self", format: "text" }
    end
    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_match(/Soliloquy report/, response.body)
  end

  test "create redirects with an alert for an unknown audience" do
    post report_path, params: { days: 7, audience: "stranger", format: "text" }
    assert_redirected_to report_path
    assert_match(/Unknown audience/, flash[:alert])
  end

  test "create redirects with an alert when there are no entries for that audience" do
    post report_path, params: { days: 7, audience: "provider", format: "text" }
    assert_redirected_to report_path
    assert_match(/No entries/, flash[:alert])
  end
end

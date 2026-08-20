require "test_helper"

class AnalysesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "show lists recent snapshots and masks configured API keys" do
    with_env(OPENROUTER_API_KEY: "sk-1234567890abcdef") do
      get analysis_path
    end
    assert_response :success
    assert_match analysis_snapshots(:one).summary, response.body
    assert_match(/sk-1\*{8}cdef/, response.body)
    assert_no_match(/sk-1234567890abcdef/, response.body)
  end

  test "show renders fine with no configured keys" do
    with_env(OPENROUTER_API_KEY: nil, GEMINI_API_KEY: nil, ANTHROPIC_API_KEY: nil) do
      get analysis_path
    end
    assert_response :success
  end
end

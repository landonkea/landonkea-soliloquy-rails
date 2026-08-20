require "test_helper"

class SharedReportsControllerTest < ActionDispatch::IntegrationTest
  test "a valid, unexpired token shows the report with no login required" do
    report = saved_reports(:one)
    token = report.share_token

    get shared_report_path(token: token)
    assert_response :success
    assert_match report.content.lines.first.strip, response.body
  end

  test "an expired token returns not found" do
    report = saved_reports(:one)
    token = report.share_token(expires_in: 1.second)

    travel 2.seconds do
      get shared_report_path(token: token)
    end
    assert_response :not_found
  end

  test "a tampered token returns not found" do
    report = saved_reports(:one)
    token = report.share_token
    get shared_report_path(token: "#{token}tampered")
    assert_response :not_found
  end
end

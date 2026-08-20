require "test_helper"

class SavedReportTest < ActiveSupport::TestCase
  test "share_token round-trips back to the same record via find_signed" do
    report = saved_reports(:one)
    token = report.share_token(expires_in: 7.days)
    assert_equal report, SavedReport.find_signed(token, purpose: SavedReport::SHARE_LINK_PURPOSE)
  end

  test "share_token expires" do
    report = saved_reports(:one)
    token = report.share_token(expires_in: 1.second)
    travel 2.seconds do
      assert_nil SavedReport.find_signed(token, purpose: SavedReport::SHARE_LINK_PURPOSE)
    end
  end

  test "a token signed for a different purpose does not resolve" do
    report = saved_reports(:one)
    token = report.signed_id(expires_in: 7.days, purpose: "something_else")
    assert_nil SavedReport.find_signed(token, purpose: SavedReport::SHARE_LINK_PURPOSE)
  end
end

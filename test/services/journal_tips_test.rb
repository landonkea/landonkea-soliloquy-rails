require "test_helper"

class JournalTipsTest < ActiveSupport::TestCase
  test "has 40 tips, ported verbatim from the original" do
    assert_equal 40, JournalTips::TIPS.size
  end

  test "for_today is deterministic for a given date" do
    date = Date.new(2026, 6, 1)
    assert_equal JournalTips.for_today(date), JournalTips.for_today(date)
  end
end

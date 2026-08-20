require "test_helper"

class JournalPromptsTest < ActiveSupport::TestCase
  test "has 116 prompts, ported verbatim from the original" do
    assert_equal 116, JournalPrompts::PROMPTS.size
  end

  test "for_today is deterministic for a given date" do
    date = Date.new(2026, 3, 15)
    assert_equal JournalPrompts.for_today(date), JournalPrompts.for_today(date)
  end

  test "for_today returns a different prompt on a different day (generally)" do
    assert_not_equal JournalPrompts.for_today(Date.new(2026, 1, 1)), JournalPrompts.for_today(Date.new(2026, 1, 2))
  end
end

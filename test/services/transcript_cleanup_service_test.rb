require "test_helper"

class TranscriptCleanupServiceTest < ActiveSupport::TestCase
  test "capitalizes sentences and adds terminal punctuation" do
    result = TranscriptCleanupService.call("this is a test this is another sentence")
    assert_equal "This is a test this is another sentence.", result
  end

  test "collapses repeated whitespace" do
    result = TranscriptCleanupService.call("hello   there\n\nworld")
    assert_equal "Hello there world.", result
  end

  test "breaks into paragraphs every four sentences" do
    text = (1..8).map { |i| "sentence number #{i}" }.join(". ") + "."
    result = TranscriptCleanupService.call(text)
    assert_equal 2, result.split("\n\n").size
  end

  test "returns an empty string unchanged" do
    assert_equal "", TranscriptCleanupService.call("")
  end
end

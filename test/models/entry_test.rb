require "test_helper"

class EntryTest < ActiveSupport::TestCase
  test "requires a transcript" do
    entry = Entry.new(user: users(:one))
    assert_not entry.valid?
    assert_includes entry.errors[:transcript], "can't be blank"
  end

  test "word_count counts words in the transcript" do
    entry = entries(:one)
    assert_equal entry.transcript.split.size, entry.word_count
  end

  test "range_between finds entries created in the given window" do
    found = users(:one).entries.range_between(3.days.ago, Time.current)
    assert_includes found, entries(:one)
    assert_includes found, entries(:two)
  end

  test "range_between excludes entries outside the window" do
    found = users(:one).entries.range_between(1.hour.ago, Time.current)
    assert_not_includes found, entries(:one)
  end

  test "search_transcripts finds entries containing the query" do
    found = users(:one).entries.search_transcripts("stressful")
    assert_includes found, entries(:two)
    assert_not_includes found, entries(:one)
  end

  test "by_tag finds entries with that exact tag" do
    found = users(:one).entries.by_tag("work")
    assert_includes found, entries(:two)
    assert_not_includes found, entries(:one)
  end

  test "all_tags returns every distinct tag in use" do
    assert_equal %w[morning walk work], users(:one).entries.all_tags.sort
  end
end

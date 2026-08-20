require "test_helper"

class EntryCreationServiceTest < ActiveSupport::TestCase
  test "add creates a brand new entry with the given transcript and tags" do
    entry = EntryCreationService.add(user: users(:one), transcript: "hello journal", tags: [ "test" ])
    assert entry.persisted?
    assert_equal "hello journal", entry.transcript
    assert_equal [ "test" ], entry.tags
  end

  test "append_or_add appends to a recent same-speaker entry from today" do
    original = EntryCreationService.add(user: users(:one), transcript: "first part", speaker: "Landon")

    entry, appended = EntryCreationService.append_or_add(user: users(:one), text: "second part", speaker: "Landon")

    assert appended
    assert_equal original.id, entry.id
    assert_equal "first part second part", entry.reload.transcript
  end

  test "append_or_add creates a new entry when the most recent one is a different speaker" do
    EntryCreationService.add(user: users(:one), transcript: "first part", speaker: "Landon")

    entry, appended = EntryCreationService.append_or_add(user: users(:one), text: "someone else's entry", speaker: "Alex")

    assert_not appended
    assert_equal "someone else's entry", entry.transcript
  end

  test "append_or_add creates a new entry when the most recent one is too old" do
    EntryCreationService.add(user: users(:one), transcript: "old entry", speaker: "Landon")
    Entry.last.update!(created_at: 2.hours.ago)

    entry, appended = EntryCreationService.append_or_add(user: users(:one), text: "new entry", speaker: "Landon", within_minutes: 60)

    assert_not appended
    assert_equal "new entry", entry.transcript
  end
end

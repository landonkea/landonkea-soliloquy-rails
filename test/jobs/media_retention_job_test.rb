require "test_helper"

class MediaRetentionJobTest < ActiveJob::TestCase
  test "does nothing when MEDIA_RETENTION_DAYS is not set" do
    entry = users(:one).entries.create!(transcript: "old entry", created_at: 400.days.ago)
    entry.audio.attach(io: File.open(Rails.root.join("test/fixtures/files/sample_audio.wav")), filename: "old.wav", content_type: "audio/wav")

    with_env(MEDIA_RETENTION_DAYS: nil) { MediaRetentionJob.perform_now }

    assert entry.reload.audio.attached?
  end

  test "purges media from entries older than the configured retention window" do
    entry = users(:one).entries.create!(transcript: "old entry", created_at: 400.days.ago)
    entry.audio.attach(io: File.open(Rails.root.join("test/fixtures/files/sample_audio.wav")), filename: "old.wav", content_type: "audio/wav")

    recent_entry = users(:one).entries.create!(transcript: "recent entry", created_at: 1.day.ago)
    recent_entry.audio.attach(io: File.open(Rails.root.join("test/fixtures/files/sample_audio.wav")), filename: "recent.wav", content_type: "audio/wav")

    with_env(MEDIA_RETENTION_DAYS: "90") { MediaRetentionJob.perform_now }

    assert_not entry.reload.audio.attached?
    assert recent_entry.reload.audio.attached?
    # The transcript itself is never touched -- only the media.
    assert_equal "old entry", entry.transcript
  end
end

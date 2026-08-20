# Opt-in: deletes attached audio/video (never the transcript) for entries older than
# $MEDIA_RETENTION_DAYS, to keep object storage growth in check over years of daily
# journaling. Off unless that env var is set -- same "protective but not free to turn
# on silently" pattern as everything else destructive in this app, matching the
# original's run_media_retention_cleanup.
class MediaRetentionJob < ApplicationJob
  queue_as :default

  def perform
    retention_days = ENV["MEDIA_RETENTION_DAYS"].presence&.to_i
    return if retention_days.nil?

    cutoff = retention_days.days.ago
    cleaned = 0

    Entry.where("created_at < ?", cutoff).find_each do |entry|
      next unless entry.audio.attached? || entry.video.attached?
      # purge deletes both the database row AND the underlying file in whichever
      # service storage.yml points at -- the Active Storage equivalent of the
      # original's ObjectStore.delete() call.
      entry.audio.purge if entry.audio.attached?
      entry.video.purge if entry.video.attached?
      cleaned += 1
    end

    Rails.logger.info("MediaRetentionJob: removed media from #{cleaned} entries older than #{retention_days} day(s).") if cleaned.positive?
  end
end

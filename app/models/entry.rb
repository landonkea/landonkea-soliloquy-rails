# ───────────────────────────────────────────────────────────────────
# entry.rb, the core data model: one journal entry
# ───────────────────────────────────────────────────────────────────
# Ported from the original Python app's entry.py + storage.py -- there,
# an Entry was a plain dataclass and EntryStore was hand-written SQL
# talking to Postgres. Here, ActiveRecord collapses both of those into
# one class: Entry IS the row, and the query methods below (range_between,
# search, by_tag, on_this_day) live right on the model as scopes, which
# is the idiomatic Rails place for "how do I ask a question about
# entries" to live.
class Entry < ApplicationRecord
  # Every entry has exactly one owner -- the person whose journal this is.
  belongs_to :user

  # Active Storage's built-in way of attaching a file to a model, no hand-rolled S3
  # client needed -- this is the direct replacement for the original's ObjectStore
  # (object_storage.py), which wrapped boto3 by hand to do the same job. Whichever
  # service config/storage.yml points at (local disk in dev, S3-compatible storage in
  # production) is invisible from here.
  has_one_attached :audio
  has_one_attached :video

  # A transcript is the one thing every entry must have -- text-only, audio, and video
  # entries all end up with a transcript one way or another (typed directly, or
  # produced by TranscriptionService).
  validates :transcript, presence: true

  # "Entries in this date range" -- the one building block every day/week/month
  # analysis window is built from, same reasoning as the original's range_between()
  # docstring: rather than writing this WHERE clause fresh every time it's needed, it
  # lives once, here.
  scope :range_between, ->(start_time, end_time) { where(created_at: start_time...end_time) }

  # Plain substring search over the transcript text. The original ran this through
  # Postgres's tsvector/plainto_tsquery full-text search machinery; SQLite has no
  # built-in equivalent that ships enabled by default, so this is an honest, simpler
  # LIKE-based search instead -- it won't handle stemming ("running" won't match
  # "run") the way real full-text search does, a real but small step down documented
  # in the README.
  scope :search_transcripts, ->(query) { where("transcript LIKE ?", "%#{sanitize_sql_like(query)}%").order(created_at: :desc) }

  # Every entry that has this exact tag somewhere in its tags array. Rails' SQLite
  # adapter stores a `json` column as a text column under the hood, so this pulls
  # matching rows out with a JSON path check rather than an array-contains operator
  # (SQLite has no native array type, unlike Postgres's text[]).
  scope :by_tag, ->(tag) { where("EXISTS (SELECT 1 FROM json_each(entries.tags) WHERE json_each.value = ?)", tag).order(created_at: :desc) }

  # Same month/day as `today`, from any earlier year -- the "on this day" resurfacing
  # feature. strftime works the same way in SQLite as Postgres's EXTRACT did in the
  # original.
  scope :on_this_day, ->(today) {
    where("date(created_at) < ?", today.to_date.iso8601)
      .where("strftime('%m', created_at) = ? AND strftime('%d', created_at) = ?", today.strftime("%m"), today.strftime("%d"))
      .order(created_at: :desc)
  }

  # Entries that still have attached media and were created before `cutoff` -- exactly
  # what the (opt-in) media retention job needs to find and clean up.
  scope :with_media_older_than, ->(cutoff) {
    where("created_at < ?", cutoff).select { |entry| entry.audio.attached? || entry.video.attached? }
  }

  # A plain word count -- used on the entries list and fed into AnalysisResult's
  # total_word_count, same simple `.split` the original's word_count property used.
  def word_count
    transcript.to_s.split.size
  end

  # Every distinct tag anyone has ever used, for populating the Entries page's filter
  # dropdown without hardcoding a tag list anywhere. Ruby-side flatten+uniq is simpler
  # than SQLite's json_each for this one, and this table is small enough (one
  # person's journal) that it's not worth a fancier query.
  def self.all_tags
    pluck(:tags).flatten.uniq.compact.sort
  end
end

# The one shared shape "what goes in a report" takes, built once from an
# AnalysisResult plus the (already audience-filtered) entries, then handed to
# whichever ReportRenderer format method is wanted. Adding a new export format later
# means adding one more render method, not touching how a report's content gets
# assembled -- same separation the original's ReportContent dataclass kept.
class ReportContent
  attr_reader :days, :audience, :entry_count, :total_word_count, :summary, :mood_notes, :key_topics, :entries

  # `entries` is an array of [created_at_iso_string, transcript] pairs, not full Entry
  # records -- a report only ever needs those two fields to print, and keeping it this
  # plain means ReportRenderer doesn't need to know anything about ActiveRecord.
  def initialize(days:, audience:, entry_count:, total_word_count:, summary:, mood_notes:, key_topics:, entries: [])
    @days = days
    @audience = audience
    @entry_count = entry_count
    @total_word_count = total_word_count
    @summary = summary
    @mood_notes = mood_notes
    @key_topics = key_topics
    @entries = entries
  end

  def self.build(result:, entries:, audience:, days:)
    new(
      days: days,
      audience: audience,
      entry_count: result.entry_count,
      total_word_count: result.total_word_count,
      summary: result.summary,
      mood_notes: result.mood_notes,
      key_topics: result.key_topics.dup,
      entries: entries.map { |entry| [ entry.created_at.iso8601, entry.transcript ] }
    )
  end

  def title
    "Soliloquy report -- last #{days} days -- audience: #{audience}"
  end

  def topics_line
    key_topics.any? ? key_topics.join(", ") : "(none noted)"
  end
end

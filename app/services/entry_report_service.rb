# ───────────────────────────────────────────────────────────────────
# EntryReportService, turns a date range of entries into analysis/reports
# ───────────────────────────────────────────────────────────────────
# Direct port of the original's actions.py -- the shared operations every entry point
# (the web controllers here, the scheduled background job, the MQTT bridge) is built
# on, so a browser-triggered report and an automatic scheduled one always run through
# identical rules instead of three separate reimplementations drifting apart.
class EntryReportService
  # Analyzes the last `days` days of a user's entries, unfiltered by sharing flags --
  # used for the "self" audience and the routine background job.
  def self.analyze_range(user:, analyzer:, days:)
    analyzer.analyze(entries_in_last_days(user, days))
  end

  # Audience-aware version: for "partner"/"provider", entries are filtered down to
  # only those explicitly marked shareable with that audience BEFORE they're handed to
  # the analyzer at all. Filtering only the displayed transcripts afterward would still
  # let a private entry leak into the AI-generated summary text itself -- the analyzer
  # must never see an entry it isn't allowed to describe. Returns [result, entries] so
  # the caller (a report renderer) has both the AI's summary and the actual filtered
  # entry list to print underneath it.
  def self.report_range(user:, analyzer:, days:, audience:)
    unless AnalyzerService::AUDIENCES.include?(audience)
      raise ArgumentError, "Unknown audience #{audience.inspect}, must be one of #{AnalyzerService::AUDIENCES}"
    end

    entries = entries_in_last_days(user, days)
    entries = entries.select(&:shareable_with_partner) if audience == "partner"
    entries = entries.select(&:shareable_with_provider) if audience == "provider"

    result = analyzer.analyze(entries, instruction: AnalyzerService::AUDIENCE_INSTRUCTIONS.fetch(audience, ""))
    [ result, entries ]
  end

  # "Journaled N of the last `window_days` days" -- an honest cadence signal, not a
  # gamified streak counter (same framing the original insisted on). Today counts as
  # one of the window's days even if it isn't over yet, the way a person would
  # naturally describe their own week.
  def self.journaling_streak(user:, window_days: 7)
    since = window_days.days.ago.beginning_of_day
    days_journaled = user.entries.where("created_at >= ?", since).pluck(:created_at).map { |t| t.to_date }.uniq.size
    [ days_journaled, window_days ]
  end

  # Entries from the same month/day as `today`, from any earlier year.
  def self.on_this_day(user:, today: Date.current)
    user.entries.on_this_day(today)
  end

  def self.entries_in_last_days(user, days)
    user.entries.range_between(days.days.ago, Time.current)
  end
  private_class_method :entries_in_last_days
end

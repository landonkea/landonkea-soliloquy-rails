# ───────────────────────────────────────────────────────────────────
# AnalysisJob, runs automatically in the background so there's usually something
# waiting on the Analysis page without anyone remembering to ask for it
# ───────────────────────────────────────────────────────────────────
# Direct port of the original's scheduler.py's run_scheduled_analysis. There, a
# separate library (APScheduler) ran this on a timer inside the same process as the
# web server; here, Rails 8's built-in Solid Queue does the same job through
# config/recurring.yml, which is the idiomatic Rails 8 way to run something "every N
# hours" without adding a whole new dependency for it.
#
# Always analyzes the "self" audience (every entry, unfiltered) -- auto-generating
# something under the partner/provider audience would mean auto-deciding what's fit to
# share, which contradicts sharing always being an explicit, later, human decision
# (see entry.rb's docstring on the sharing flags).
class AnalysisJob < ApplicationJob
  queue_as :default

  # `days` defaults to 1 -- how many days of entries each run covers, configurable via
  # config/recurring.yml's args the same way the original read $ANALYSIS_WINDOW_DAYS.
  def perform(days: ENV.fetch("ANALYSIS_WINDOW_DAYS", "1").to_i)
    User.find_each do |user|
      run_for(user, days)
    end
  end

  private

  def run_for(user, days)
    result, _entries = EntryReportService.report_range(
      user: user, analyzer: AnalyzerService.default_analyzer, days: days, audience: "self"
    )
    user.analysis_snapshots.create!(
      days: days, audience: "self", entry_count: result.entry_count, total_word_count: result.total_word_count,
      summary: result.summary, mood_notes: result.mood_notes, key_topics: result.key_topics, mood_score: result.mood_score
    )
    Rails.logger.info("AnalysisJob: saved a snapshot for user #{user.id} (#{result.entry_count} entries, last #{days} day(s)).")
  rescue Analyzers::NoEntriesError
    # Nothing to analyze yet for this user -- not an error, just skip and move on,
    # same as the original logging "skipped" instead of raising.
    Rails.logger.info("AnalysisJob: skipped user #{user.id} -- no entries in the last #{days} day(s).")
  rescue RuntimeError => e
    # A background job failing shouldn't crash the whole process -- logged, not
    # re-raised, matching the original's own reasoning.
    Rails.logger.warn("AnalysisJob: failed for user #{user.id}: #{e.message}")
  end
end

# Generates and saves a 30-day "self" report once a month -- a standing monthly record
# without remembering to click "Generate" on the Report page, same idea as the
# original's run_scheduled_monthly_report. Actually emailing/delivering it isn't
# built here either, same honest limitation the original flagged (this app has no
# outbound email setup to plug it into).
class MonthlyReportJob < ApplicationJob
  queue_as :default

  MONTHLY_REPORT_DAYS = 30

  def perform
    User.find_each { |user| run_for(user) }
  end

  private

  def run_for(user)
    result, entries = EntryReportService.report_range(
      user: user, analyzer: AnalyzerService.default_analyzer, days: MONTHLY_REPORT_DAYS, audience: "self"
    )
    content = ReportContent.build(result: result, entries: entries, audience: "self", days: MONTHLY_REPORT_DAYS)
    user.saved_reports.create!(
      days: MONTHLY_REPORT_DAYS, audience: "self", content: ReportRenderer.render(content, "markdown"), source: "scheduled"
    )
    Rails.logger.info("MonthlyReportJob: saved a report for user #{user.id} (#{result.entry_count} entries).")
  rescue Analyzers::NoEntriesError
    Rails.logger.info("MonthlyReportJob: skipped user #{user.id} -- no entries in the last #{MONTHLY_REPORT_DAYS} days.")
  rescue RuntimeError => e
    Rails.logger.warn("MonthlyReportJob: failed for user #{user.id}: #{e.message}")
  end
end

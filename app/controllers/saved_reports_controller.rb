# Saved reports (kept for later reference) and creating expiring, signed share links
# for them -- mirrors the original's /reports/saved (list), /reports/save (generate +
# keep), and the share-link-creation part of report_store.py.
class SavedReportsController < ApplicationController
  def index
    @reports = Current.user.saved_reports.recent
    @tip = JournalTips.for_today
  end

  def create
    days = params[:days].presence&.to_i || 30
    audience = params[:audience].presence || "self"

    unless AnalyzerService::AUDIENCES.include?(audience)
      redirect_to reports_saved_path, alert: "Unknown audience #{audience.inspect}." and return
    end

    result, entries = EntryReportService.report_range(
      user: Current.user, analyzer: AnalyzerService.default_analyzer, days: days, audience: audience
    )
    content = ReportContent.build(result: result, entries: entries, audience: audience, days: days)
    Current.user.saved_reports.create!(
      days: days, audience: audience, content: ReportRenderer.render(content, "markdown"), source: "manual"
    )
    redirect_to reports_saved_path, notice: "Report saved."
  rescue Analyzers::NoEntriesError
    redirect_to reports_saved_path, alert: "No entries for audience '#{audience}' in the last #{days} days."
  rescue RuntimeError => e
    redirect_to reports_saved_path, alert: e.message
  end

  # Creates a signed, expiring token for one saved report and shows the link back to
  # the person so they can copy it -- the token itself IS the access control for the
  # public /reports/shared/:token route (see SharedReportsController), no login
  # required to view it, matching the original's whole reason for this feature.
  def share_link
    report = Current.user.saved_reports.find(params[:id])
    expires_in_days = (params[:expires_in_days].presence || SavedReport::DEFAULT_SHARE_LINK_EXPIRY.in_days.to_i).to_i
    token = report.share_token(expires_in: expires_in_days.days)
    redirect_to reports_saved_path, notice: "Share link (expires in #{expires_in_days} days): #{shared_report_url(token: token)}"
  end
end

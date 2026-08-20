# The Report page: pick a day range, an audience, and a format, and get a real
# generated report back. Mirrors the original's report_page (GET /report) + post_report
# (POST /reports), just combined into REST-ish new/create actions on one controller.
class ReportsController < ApplicationController
  # (media type, file extension) per format -- one small table instead of two parallel
  # conditionals that could drift out of sync, same idea as the original's
  # _REPORT_FORMATS dict.
  FORMAT_HEADERS = {
    "text" => [ "text/plain", "txt" ],
    "markdown" => [ "text/markdown", "md" ],
    "html" => [ "text/html", "html" ],
    "pdf" => [ "application/pdf", "pdf" ]
  }.freeze

  def new
    @audiences = AnalyzerService::AUDIENCES
    @tip = JournalTips.for_today
  end

  def create
    days = params[:days].to_i
    audience = params[:audience].presence || "self"
    format = params[:format].presence || "text"

    unless AnalyzerService::AUDIENCES.include?(audience)
      redirect_to report_path, alert: "Unknown audience #{audience.inspect}." and return
    end
    unless ReportRenderer::FORMATS.include?(format)
      redirect_to report_path, alert: "Unknown format #{format.inspect}." and return
    end

    result, entries = EntryReportService.report_range(
      user: Current.user, analyzer: AnalyzerService.default_analyzer, days: days, audience: audience
    )
    content = ReportContent.build(result: result, entries: entries, audience: audience, days: days)
    media_type, extension = FORMAT_HEADERS.fetch(format)

    send_data ReportRenderer.render(content, format),
              type: media_type,
              filename: "soliloquy-report.#{extension}",
              disposition: "attachment"
  rescue Analyzers::NoEntriesError
    redirect_to report_path, alert: "No entries for audience '#{audience}' in the last #{days} days."
  rescue RuntimeError => e
    # Every analyzer provider raises a plain RuntimeError for a missing API key or a
    # failed API call -- surfaced here as a real, readable message instead of a blank
    # 500, so "you forgot to set an API key" is actually visible.
    redirect_to report_path, alert: e.message
  end
end

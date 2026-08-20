# The Analysis page -- read-only, just shows whatever AnalysisSnapshots already exist
# (mostly written by the recurring background job, see config/recurring.yml and
# AnalysisJob) plus the mood trend chart built from them. Mirrors the original's
# analysis_page route.
class AnalysesController < ApplicationController
  def show
    @snapshots = Current.user.analysis_snapshots.recent(10)
    chart_snapshots = Current.user.analysis_snapshots.recent(20)
    @tip = JournalTips.for_today
    # MoodChartService wants oldest-first; .recent is newest-first, hence the reverse
    # -- same as the original's `list(reversed(chart_snapshots))`.
    @mood_chart_svg = MoodChartService.render(chart_snapshots.reverse)
    @api_keys = analyzer_key_status
  end

  private

  # Shows just enough of each configured API key to confirm "yes, something is set"
  # without ever putting the real secret into rendered HTML -- read-only status
  # indicators, matching the original's _masked_key/_analyzer_key_status.
  def analyzer_key_status
    [
      { label: "OpenRouter", env_var: "OPENROUTER_API_KEY", masked: masked_key(ENV["OPENROUTER_API_KEY"]) },
      { label: "Gemini", env_var: "GEMINI_API_KEY", masked: masked_key(ENV["GEMINI_API_KEY"]) },
      { label: "Claude (optional)", env_var: "ANTHROPIC_API_KEY", masked: masked_key(ENV["ANTHROPIC_API_KEY"]) }
    ]
  end

  def masked_key(value)
    return "" if value.blank?
    return "*" * value.length if value.length <= 8
    "#{value[0, 4]}#{'*' * 8}#{value[-4, 4]}"
  end
end

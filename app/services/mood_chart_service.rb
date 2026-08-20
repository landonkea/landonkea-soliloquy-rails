# ───────────────────────────────────────────────────────────────────
# MoodChartService, a tiny inline SVG line chart for mood_score over time
# ───────────────────────────────────────────────────────────────────
# Direct port of the original's mood_chart.py -- server-rendered on purpose, matching
# how the rest of this app avoids a separate JS charting library/build step. Returns a
# plain SVG string the Analysis view drops straight into the page with `.html_safe`,
# not a client-side charting dependency. Deliberately minimal: one line, no axes or
# legend -- this is "here's roughly how mood has been trending," not a dashboard.
class MoodChartService
  WIDTH = 640
  HEIGHT = 120
  PADDING = 12

  # `snapshots` should be oldest-first -- callers typically have them newest-first
  # (AnalysisSnapshot.recent), so reverse before calling this, same as the original.
  # Returns nil if fewer than 2 snapshots have a real mood_score -- a single point (or
  # none) isn't a "trend" worth drawing.
  def self.render(snapshots)
    new(snapshots).render
  end

  def initialize(snapshots)
    @scored = snapshots.select { |snapshot| snapshot.mood_score.present? }
  end

  def render
    return nil if @scored.size < 2

    plot_width = WIDTH - (2 * PADDING)
    plot_height = HEIGHT - (2 * PADDING)
    step = plot_width.to_f / (@scored.size - 1)

    points = @scored.each_with_index.map { |snapshot, i|
      "#{format('%.1f', PADDING + (i * step))},#{format('%.1f', y_for(snapshot.mood_score, plot_height))}"
    }.join(" ")

    dots = @scored.each_with_index.map { |snapshot, i|
      x = format("%.1f", PADDING + (i * step))
      y = format("%.1f", y_for(snapshot.mood_score, plot_height))
      %(<circle cx="#{x}" cy="#{y}" r="3" fill="var(--color-accent, #ea580c)"/>)
    }.join

    <<~SVG.strip
      <svg viewBox="0 0 #{WIDTH} #{HEIGHT}" width="100%" height="#{HEIGHT}" role="img" aria-label="Mood trend over time">
      <polyline points="#{points}" fill="none" stroke="var(--color-accent, #ea580c)" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>
      #{dots}
      </svg>
    SVG
  end

  private

  # mood_score runs 1-10 -- mapped so 10 (great) lands at the top of the chart and 1
  # (rough) at the bottom, the orientation a reader expects from a "how have I been
  # doing" line.
  def y_for(score, plot_height)
    PADDING + (plot_height * (1 - ((score - 1) / 9.0)))
  end
end

# A plain value object holding one AI analysis result -- the Ruby equivalent of the
# original's AnalysisResult dataclass (analyzer.py). Not an ActiveRecord model on
# purpose: this is what an Analyzer hands back before it's decided whether to save it
# as an AnalysisSnapshot, render it into a report, or just show it on a page, the same
# separation the original kept between "the result of analyzing" and "where a result
# gets stored."
class AnalysisResult
  attr_reader :entry_count, :total_word_count, :summary, :mood_notes, :key_topics, :mood_score

  def initialize(entry_count:, total_word_count:, summary:, mood_notes:, key_topics:, mood_score: nil)
    @entry_count = entry_count
    @total_word_count = total_word_count
    @summary = summary
    @mood_notes = mood_notes
    @key_topics = key_topics
    # 1 (rough) to 10 (great) -- the model's own casual read, not a clinical score.
    # nil when a provider's response didn't include a usable one; callers (the mood
    # chart) just skip a nil point rather than plotting a made-up number.
    @mood_score = mood_score
  end
end

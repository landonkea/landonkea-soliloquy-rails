# ───────────────────────────────────────────────────────────────────
# AnalyzerService, picks which AI provider actually runs analysis
# ───────────────────────────────────────────────────────────────────
# Direct port of the original's build_free_analyzer()/get_default_analyzer() module
# functions (analyzer.py) -- collected here as class methods since Ruby doesn't have
# Python's "just define functions at module level" convention as naturally.
class AnalyzerService
  # OpenRouter's catalog of free-tagged models changes over time -- a reasonable
  # default set as of this rewrite, not a promise any of them stay free/available
  # forever. Same three the original shipped with.
  DEFAULT_OPENROUTER_FREE_MODELS = %w[
    meta-llama/llama-3.1-8b-instruct:free
    google/gemma-2-9b-it:free
    mistralai/mistral-7b-instruct:free
  ].freeze

  # The three audiences a report/analysis can be generated for -- matches the
  # original's actions.AUDIENCES exactly.
  AUDIENCES = %w[self partner provider].freeze

  # Extra framing appended to the analysis prompt per audience -- the sharing flags
  # already control WHICH entries an audience's report can see (see
  # EntryReportService); this only changes how the analyzer talks about them. Empty
  # for "self": no extra framing needed when the reader is the journal's own owner.
  AUDIENCE_INSTRUCTIONS = {
    "self" => "",
    "partner" => "Focus on emotional patterns and relationship-relevant context a partner would find meaningful, not routine day-to-day logistics.",
    "provider" => "Focus on patterns clinically relevant to therapy (mood trends, recurring stressors, coping attempts), not routine daily detail."
  }.freeze

  # The $0 default chain: try each OpenRouter free-tagged model in order, then fall
  # back to Gemini's free tier. A provider with no key configured just fails over to
  # the next one (see Analyzers::FallbackAnalyzer), so this works fine with only one
  # of OPENROUTER_API_KEY/GEMINI_API_KEY actually set.
  def self.free_analyzer(openrouter_models: DEFAULT_OPENROUTER_FREE_MODELS, gemini_model: Analyzers::GeminiAnalyzer::DEFAULT_MODEL)
    providers = openrouter_models.map { |model| Analyzers::OpenRouterAnalyzer.new(model: model) }
    providers << Analyzers::GeminiAnalyzer.new(model: gemini_model)
    Analyzers::FallbackAnalyzer.new(providers)
  end

  # Chosen via $ANALYZER_PROVIDER: "free" (the default) uses free_analyzer above, or
  # "claude" uses ClaudeAnalyzer directly. "free" is the default specifically so
  # running this app doesn't cost anything unless someone explicitly opts into Claude.
  def self.default_analyzer
    case ENV.fetch("ANALYZER_PROVIDER", "free")
    when "claude" then Analyzers::ClaudeAnalyzer.new
    when "free" then free_analyzer
    else raise "Unknown ANALYZER_PROVIDER #{ENV['ANALYZER_PROVIDER'].inspect}, must be 'free' or 'claude'"
    end
  end
end

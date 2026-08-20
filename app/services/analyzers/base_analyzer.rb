# ───────────────────────────────────────────────────────────────────
# Analyzers::BaseAnalyzer, shared prompt/request/parsing logic
# ───────────────────────────────────────────────────────────────────
# Every concrete analyzer below (Claude, OpenRouter, Gemini) is a real HTTP call to a
# different provider, but they all get asked the exact same question in the exact same
# way and are expected to answer in the exact same JSON shape -- so that logic (the
# prompt text, and parsing the response back into an AnalysisResult) lives once, here,
# instead of three times. Direct port of the original's _HttpAnalyzer plus its
# module-level _build_prompt/_parse_response/_strip_code_fence functions.
module Analyzers
  # NoEntriesError and RateLimitError live in their own files (analyzers/no_entries_error.rb,
  # analyzers/rate_limit_error.rb) so Rails' autoloader can find them directly, even
  # from code that references one without ever loading this class first.

  class BaseAnalyzer
    # Subclasses set these two: `key_label` for the "no API key found" message (e.g.
    # "Anthropic"), and `api_key_env_var` for which environment variable actually holds
    # the key (e.g. "ANTHROPIC_API_KEY").
    def self.key_label = raise NotImplementedError
    def self.api_key_env_var = raise NotImplementedError

    def initialize(api_key: nil)
      # Falls back to the environment, same convention the original used, but still
      # accepts an explicit key so tests don't have to mutate real process-wide
      # environment variables.
      @api_key = api_key || ENV[self.class.api_key_env_var] || ""
    end

    # Used in error messages -- overridden by providers that vary by model
    # (OpenRouter, Gemini) to name which specific model failed, so a chained failure
    # from FallbackAnalyzer stays debuggable about exactly what went wrong where.
    def label
      self.class.key_label
    end

    def analyze(entries, instruction: "")
      raise NoEntriesError, "Cannot analyze an empty list of entries." if entries.empty?
      if @api_key.blank?
        raise "No #{self.class.key_label} API key found. Set #{self.class.api_key_env_var} or pass api_key: explicitly."
      end

      response = request(build_prompt(entries, instruction))
      raise RateLimitError, "#{label} rate limited: #{response.body}" if response.status == 429
      raise "#{label} API error: #{response.status} #{response.body}" unless response.status == 200

      text = extract_text(response.body)
      parse_response(text, entries)
    rescue KeyError, NoMethodError => e
      raise "Unexpected #{label} response shape: #{e.message}"
    end

    private

    # Subclasses implement these two: how to make the actual HTTP request, and how to
    # pull the model's text reply out of that provider's particular response shape.
    def request(prompt) = raise NotImplementedError
    def extract_text(body) = raise NotImplementedError

    def build_prompt(entries, instruction)
      entries_block = entries.map { |entry| "[#{entry.created_at.iso8601}] #{entry.transcript}" }.join("\n\n")

      # Empty for "self" (the default audience) -- this only adds extra framing when a
      # caller explicitly asks for it (e.g. steering a provider-bound report toward
      # clinically relevant patterns instead of day-to-day detail).
      audience_line = instruction.present? ? "\n\nSpecifically for this audience: #{instruction}" : ""

      <<~PROMPT.strip
        You are analyzing a personal voice journal's entries for the writer's own review (and possibly to share with a therapist). Be honest and specific, not generic or falsely upbeat. Respond with ONLY a JSON object, no other text, in exactly this shape:
        {"summary": "a few honest sentences about what stands out across these entries", "mood_notes": "a few sentences specifically about emotional tone/trends, if any are genuinely visible -- say so plainly if the entries don't show a clear trend, don't invent one", "mood_score": an integer 1-10, your own rough read of overall mood across these entries (1 = very rough, 10 = great, 5 = neutral or genuinely mixed), "key_topics": ["topic1", "topic2", ...]}#{audience_line}

        Entries:

        #{entries_block}
      PROMPT
    end

    # Smaller/free models often wrap their JSON reply in a ```json ... ``` fence
    # regardless of instructions -- stripped here so every provider's response goes
    # through the exact same JSON parsing step, not just the well-behaved ones.
    def strip_code_fence(text)
      text = text.strip
      return text unless text.start_with?("```")

      lines = text.lines
      text = lines.size > 1 ? lines[1..].join : text
      text = text.delete_suffix("```").strip
      text = text.delete_prefix("json").strip if text.start_with?("json")
      text
    end

    def parse_response(response_text, entries)
      cleaned = strip_code_fence(response_text)
      parsed = JSON.parse(cleaned)

      %w[summary mood_notes key_topics].each do |required_key|
        unless parsed.key?(required_key)
          raise "#{label}'s response is missing required key \"#{required_key}\": #{parsed.inspect}"
        end
      end

      # mood_score is asked for but not required -- a provider that ignores it (or
      # returns something unparseable) shouldn't fail the whole analysis over one
      # chart data point.
      mood_score = begin
        raw = parsed["mood_score"]
        raw.nil? ? nil : raw.to_i.clamp(1, 10)
      rescue StandardError
        nil
      end

      AnalysisResult.new(
        entry_count: entries.size,
        total_word_count: entries.sum(&:word_count),
        summary: parsed["summary"],
        mood_notes: parsed["mood_notes"],
        key_topics: Array(parsed["key_topics"]),
        mood_score: mood_score
      )
    rescue JSON::ParserError
      raise "#{label} did not return valid JSON: #{response_text.inspect}"
    end
  end
end

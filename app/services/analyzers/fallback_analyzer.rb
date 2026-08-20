# Tries each provider in the given order, moving on to the next on ANY failure --
# missing/invalid key, rate limit, malformed response. Only raises once every provider
# has failed, and that error lists what each one said, so a whole chain of free
# providers failing is still debuggable instead of silently swallowed. Direct port of
# the original's FallbackAnalyzer.
module Analyzers
  class FallbackAnalyzer
    def initialize(providers)
      raise ArgumentError, "FallbackAnalyzer needs at least one provider" if providers.empty?
      @providers = providers
    end

    def analyze(entries, instruction: "")
      # Checked once, up front, rather than letting every provider individually
      # discover and raise the same NoEntriesError -- an empty entry list isn't a
      # provider-specific problem, so there's no reason to try (and fail) each one to
      # find that out.
      raise NoEntriesError, "Cannot analyze an empty list of entries." if entries.empty?

      errors = []
      @providers.each do |provider|
        begin
          return provider.analyze(entries, instruction: instruction)
        rescue StandardError => e
          errors << "#{provider.class.name}: #{e.message}"
        end
      end

      raise "All analyzer providers failed:\n#{errors.join("\n")}"
    end
  end
end

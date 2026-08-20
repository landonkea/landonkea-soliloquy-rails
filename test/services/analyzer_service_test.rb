require "test_helper"

class AnalyzerServiceTest < ActiveSupport::TestCase
  test "default_analyzer returns a free FallbackAnalyzer chain by default" do
    with_env(ANALYZER_PROVIDER: nil) do
      analyzer = AnalyzerService.default_analyzer
      assert_instance_of Analyzers::FallbackAnalyzer, analyzer
    end
  end

  test "default_analyzer returns ClaudeAnalyzer when ANALYZER_PROVIDER=claude" do
    with_env(ANALYZER_PROVIDER: "claude") do
      assert_instance_of Analyzers::ClaudeAnalyzer, AnalyzerService.default_analyzer
    end
  end

  test "default_analyzer raises for an unknown provider name" do
    with_env(ANALYZER_PROVIDER: "not-a-real-provider") do
      assert_raises(RuntimeError) { AnalyzerService.default_analyzer }
    end
  end

  test "free_analyzer chains every OpenRouter model plus Gemini" do
    analyzer = AnalyzerService.free_analyzer
    assert_instance_of Analyzers::FallbackAnalyzer, analyzer
    providers = analyzer.instance_variable_get(:@providers)
    assert_equal AnalyzerService::DEFAULT_OPENROUTER_FREE_MODELS.size + 1, providers.size
    assert_instance_of Analyzers::GeminiAnalyzer, providers.last
  end
end

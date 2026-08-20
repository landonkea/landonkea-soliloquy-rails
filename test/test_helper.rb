ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

# Intercepts every outbound HTTP call made during the test suite -- the transcription
# service and the AI analyzers all talk to real third-party APIs in production, and
# tests should never actually hit those (slow, costs real money, needs a real key).
# WebMock::API gets mixed into every test below, so each test can stub exactly the
# request it expects with `stub_request`.
require "webmock/minitest"

# Minitest::Mock (used by the FallbackAnalyzer tests to prove "the next provider only
# gets tried after the first one fails") isn't auto-required by rails/test_help.
require "minitest/mock"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Temporarily sets (or removes, when a value is nil) the given environment
    # variables for the duration of the block, then restores whatever was there
    # before -- used by the transcription/analyzer service tests, which need to
    # exercise both "a key IS configured" and "a key is NOT configured" without
    # permanently mutating the real process environment other tests also run in.
    def with_env(vars)
      # ENV only accepts string keys (a symbol raises TypeError), so every key gets
      # normalized with .to_s before touching ENV at all -- callers can still pass the
      # more natural-looking symbol keys (with_env(FOO: "bar")).
      vars = vars.transform_keys(&:to_s)
      original = vars.keys.index_with { |key| ENV[key] }
      vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      yield
    ensure
      original&.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end
  end
end

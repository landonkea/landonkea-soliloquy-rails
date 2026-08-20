require "test_helper"
require "tempfile"

class TranscriptionServiceTest < ActiveSupport::TestCase
  setup do
    @audio_file = Tempfile.new([ "test-audio", ".wav" ])
    @audio_file.write("not real audio, just bytes for the request body")
    @audio_file.rewind
  end

  teardown { @audio_file.close! }

  test "raises a clear error when no API key is configured" do
    with_env(TRANSCRIPTION_API_KEY: nil) do
      error = assert_raises(TranscriptionService::TranscriptionError) do
        TranscriptionService.call(@audio_file.path)
      end
      assert_match(/TRANSCRIPTION_API_KEY/, error.message)
    end
  end

  test "returns the transcribed text on a successful response" do
    stub_request(:post, TranscriptionService::DEFAULT_API_URL)
      .to_return(status: 200, body: { text: "hello from the stub" }.to_json, headers: { "Content-Type" => "application/json" })

    with_env(TRANSCRIPTION_API_KEY: "fake-key") do
      assert_equal "hello from the stub", TranscriptionService.call(@audio_file.path)
    end
  end

  test "raises on a non-success response" do
    stub_request(:post, TranscriptionService::DEFAULT_API_URL).to_return(status: 500, body: "server exploded")

    with_env(TRANSCRIPTION_API_KEY: "fake-key") do
      error = assert_raises(TranscriptionService::TranscriptionError) { TranscriptionService.call(@audio_file.path) }
      assert_match(/500/, error.message)
    end
  end

  test "raises when the response shape is unrecognized" do
    stub_request(:post, TranscriptionService::DEFAULT_API_URL)
      .to_return(status: 200, body: { unexpected: "shape" }.to_json, headers: { "Content-Type" => "application/json" })

    with_env(TRANSCRIPTION_API_KEY: "fake-key") do
      assert_raises(TranscriptionService::TranscriptionError) { TranscriptionService.call(@audio_file.path) }
    end
  end
end

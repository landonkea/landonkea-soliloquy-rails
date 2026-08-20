require "test_helper"

class AudioEntryCreationServiceTest < ActiveSupport::TestCase
  SAMPLE_AUDIO = Rails.root.join("test/fixtures/files/sample_audio.wav")

  test "normalizes, transcribes, cleans up, and saves a real Entry with attached audio" do
    stub_request(:post, TranscriptionService::DEFAULT_API_URL)
      .to_return(status: 200, body: { text: "this is a test recording it went well" }.to_json, headers: { "Content-Type" => "application/json" })

    # ActionDispatch::Http::UploadedFile is exactly what a real multipart form upload
    # hands a controller -- building one directly here means this test exercises the
    # real interface AudioEntryCreationService expects (.tempfile.path), without
    # needing a full integration request just to get one.
    uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(SAMPLE_AUDIO), filename: "sample_audio.wav", type: "audio/wav"
    )

    entry = with_env(TRANSCRIPTION_API_KEY: "fake-key") do
      AudioEntryCreationService.call(user: users(:one), uploaded_file: uploaded_file)
    end

    assert entry.persisted?
    assert entry.audio.attached?
    # TranscriptCleanupService should have capitalized/punctuated the raw transcript.
    assert_equal "This is a test recording it went well.", entry.transcript
  end
end

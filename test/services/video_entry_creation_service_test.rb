require "test_helper"

class VideoEntryCreationServiceTest < ActiveSupport::TestCase
  SAMPLE_VIDEO = Rails.root.join("test/fixtures/files/sample_video.mp4")

  test "extracts audio, transcribes, and saves a real Entry with both video and audio attached" do
    stub_request(:post, TranscriptionService::DEFAULT_API_URL)
      .to_return(status: 200, body: { text: "a video journal entry" }.to_json, headers: { "Content-Type" => "application/json" })

    uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(SAMPLE_VIDEO), filename: "sample_video.mp4", type: "video/mp4"
    )

    entry = with_env(TRANSCRIPTION_API_KEY: "fake-key") do
      VideoEntryCreationService.call(user: users(:one), uploaded_file: uploaded_file)
    end

    assert entry.persisted?
    assert entry.video.attached?
    assert entry.audio.attached?
    assert_equal "A video journal entry.", entry.transcript
  end

  test "raises ExtractionError for a video ffmpeg cannot read" do
    bad_file = Tempfile.new([ "not-real-video", ".mp4" ])
    bad_file.write("definitely not a real video")
    bad_file.rewind
    uploaded_file = ActionDispatch::Http::UploadedFile.new(tempfile: bad_file, filename: "bad.mp4", type: "video/mp4")

    assert_raises(VideoEntryCreationService::ExtractionError) do
      VideoEntryCreationService.call(user: users(:one), uploaded_file: uploaded_file)
    end
  ensure
    bad_file&.close!
  end
end

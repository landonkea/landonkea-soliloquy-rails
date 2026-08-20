require "test_helper"

class EntriesMediaControllerTest < ActionDispatch::IntegrationTest
  SAMPLE_AUDIO = Rails.root.join("test/fixtures/files/sample_audio.wav")
  SAMPLE_VIDEO = Rails.root.join("test/fixtures/files/sample_video.mp4")

  setup { sign_in_as(users(:one)) }

  test "create_audio uploads, transcribes, and redirects" do
    stub_request(:post, TranscriptionService::DEFAULT_API_URL)
      .to_return(status: 200, body: { text: "a spoken entry" }.to_json, headers: { "Content-Type" => "application/json" })

    with_env(TRANSCRIPTION_API_KEY: "fake-key") do
      assert_difference("users(:one).entries.count", 1) do
        post audio_entries_path, params: { audio_file: Rack::Test::UploadedFile.new(SAMPLE_AUDIO.to_s, "audio/wav") }
      end
    end
    assert_redirected_to root_path
  end

  test "create_audio redirects with an alert when transcription fails" do
    stub_request(:post, TranscriptionService::DEFAULT_API_URL).to_return(status: 500, body: "nope")

    with_env(TRANSCRIPTION_API_KEY: "fake-key") do
      assert_no_difference("users(:one).entries.count") do
        post audio_entries_path, params: { audio_file: Rack::Test::UploadedFile.new(SAMPLE_AUDIO.to_s, "audio/wav") }
      end
    end
    assert_redirected_to new_entry_path
    assert flash[:alert].present?
  end

  test "create_video uploads, extracts audio, transcribes, and redirects" do
    stub_request(:post, TranscriptionService::DEFAULT_API_URL)
      .to_return(status: 200, body: { text: "a video entry" }.to_json, headers: { "Content-Type" => "application/json" })

    with_env(TRANSCRIPTION_API_KEY: "fake-key") do
      assert_difference("users(:one).entries.count", 1) do
        post video_entries_path, params: { video_file: Rack::Test::UploadedFile.new(SAMPLE_VIDEO.to_s, "video/mp4") }
      end
    end
    assert_redirected_to root_path
  end
end

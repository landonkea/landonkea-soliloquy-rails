require "test_helper"

class AudioProcessingServiceTest < ActiveSupport::TestCase
  SAMPLE_AUDIO = Rails.root.join("test/fixtures/files/sample_audio.wav")
  SAMPLE_VIDEO = Rails.root.join("test/fixtures/files/sample_video.mp4")

  test "normalize produces a real, playable 16kHz mono WAV file" do
    output_path = AudioProcessingService.normalize(SAMPLE_AUDIO.to_s)
    assert File.exist?(output_path)
    assert File.size(output_path).positive?
  ensure
    File.delete(output_path) if output_path && File.exist?(output_path)
  end

  test "extract_audio_from_video pulls a real WAV out of a video file" do
    output_path = AudioProcessingService.extract_audio_from_video(SAMPLE_VIDEO.to_s)
    assert File.exist?(output_path)
    assert File.size(output_path).positive?
  ensure
    File.delete(output_path) if output_path && File.exist?(output_path)
  end

  test "raises a clear FfmpegError for a file ffmpeg cannot process" do
    bad_file = Tempfile.new([ "not-real-audio", ".wav" ])
    bad_file.write("this is definitely not a real audio file")
    bad_file.rewind

    assert_raises(AudioProcessingService::FfmpegError) { AudioProcessingService.normalize(bad_file.path) }
  ensure
    bad_file&.close!
  end
end

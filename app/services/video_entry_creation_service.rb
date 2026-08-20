# ───────────────────────────────────────────────────────────────────
# VideoEntryCreationService, upload video -> keep it -> extract+transcribe its audio
# ───────────────────────────────────────────────────────────────────
# Direct port of the original's post_video_entry: store the video as-is, pull its
# audio track out with ffmpeg, then run that extracted audio through the exact same
# normalize -> transcribe -> clean pipeline a plain audio upload uses
# (AudioEntryCreationService), so the transcript/analysis code never has to know or
# care whether an entry started life as audio or video.
class VideoEntryCreationService
  class ExtractionError < StandardError; end

  def self.call(user:, uploaded_file:)
    new(user, uploaded_file).call
  end

  def initialize(user, uploaded_file)
    @user = user
    @uploaded_file = uploaded_file
  end

  def call
    video_path = @uploaded_file.tempfile.path

    begin
      extracted_audio_path = AudioProcessingService.extract_audio_from_video(video_path)
    rescue AudioProcessingService::FfmpegError => e
      raise ExtractionError, "Could not extract audio from video: #{e.message}"
    end

    normalized_path = AudioProcessingService.normalize(extracted_audio_path)

    begin
      raw_transcript = TranscriptionService.call(normalized_path)
      transcript = TranscriptCleanupService.call(raw_transcript)

      # Saved first, same reasoning as AudioEntryCreationService: attaching before
      # save on a not-yet-persisted record defers the actual upload until save,
      # which needs the IO handles to still be open at that later point -- attaching
      # after save avoids that entirely.
      entry = @user.entries.create!(transcript: transcript)
      File.open(video_path, "rb") do |file|
        entry.video.attach(
          io: file,
          filename: @uploaded_file.original_filename.presence || "entry-#{SecureRandom.uuid}.mp4",
          content_type: @uploaded_file.content_type.presence || "video/mp4"
        )
      end
      File.open(normalized_path, "rb") do |file|
        entry.audio.attach(io: file, filename: "entry-#{SecureRandom.uuid}.wav", content_type: "audio/wav")
      end
      entry
    ensure
      File.delete(extracted_audio_path) if File.exist?(extracted_audio_path)
      File.delete(normalized_path) if File.exist?(normalized_path)
    end
  end
end

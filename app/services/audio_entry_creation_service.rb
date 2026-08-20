# ───────────────────────────────────────────────────────────────────
# AudioEntryCreationService, upload -> normalize -> transcribe -> save
# ───────────────────────────────────────────────────────────────────
# Ties together AudioProcessingService, TranscriptionService, and
# TranscriptCleanupService into the one real pipeline an uploaded audio file goes
# through, mirroring the original web/app.py's _upload_and_transcribe_audio +
# post_audio_entry. Both the plain audio upload route and the video upload route (see
# VideoEntryCreationService, whose extracted audio track goes through this exact same
# class) share this one path.
class AudioEntryCreationService
  # `uploaded_file` is an ActionDispatch::Http::UploadedFile (what Rails hands a
  # controller from a multipart form upload) -- it already has a real temp file on
  # disk at .tempfile.path, so there's no need to write it out by hand first.
  def self.call(user:, uploaded_file:)
    new(user, uploaded_file).call
  end

  def initialize(user, uploaded_file)
    @user = user
    @uploaded_file = uploaded_file
  end

  def call
    normalized_path = AudioProcessingService.normalize(@uploaded_file.tempfile.path)

    begin
      raw_transcript = TranscriptionService.call(normalized_path)
      transcript = TranscriptCleanupService.call(raw_transcript)

      # Saved BEFORE attaching audio, deliberately: Active Storage defers an attach
      # made on a not-yet-saved record until save actually runs, which means the IO
      # handle needs to still be open at THAT point -- attaching after save instead
      # sidesteps that entirely and uploads the file immediately.
      entry = @user.entries.create!(transcript: transcript)
      # File.open here, not the uploaded_file's own tempfile -- entry.audio should be
      # the CLEANED, normalized audio (what got transcribed), not the raw upload, so
      # playback and the transcript always describe the exact same recording.
      File.open(normalized_path, "rb") do |file|
        entry.audio.attach(io: file, filename: "entry-#{SecureRandom.uuid}.wav", content_type: "audio/wav")
      end
      entry
    ensure
      File.delete(normalized_path) if File.exist?(normalized_path)
    end
  end
end

# ───────────────────────────────────────────────────────────────────
# AudioProcessingService, cleans up raw audio before transcription/storage
# ───────────────────────────────────────────────────────────────────
# HONEST DEVIATION FROM THE ORIGINAL: the Python app's noise_reduction.py ran two
# separate steps -- DeepFilterNet3 (a neural network that isolates speech from
# background noise) and THEN ffmpeg loudness normalization. DeepFilterNet has no Ruby
# equivalent (it's a PyTorch model with no comparable Ruby binding or port), so the
# neural voice-isolation step is not reproduced here -- that's a real capability this
# rewrite doesn't have, called out plainly rather than faked.
#
# What IS reproduced faithfully: the ffmpeg loudness normalization pass. ffmpeg is a
# real system binary (not a Python-specific dependency), works identically from Ruby,
# and the original's exact filter chain (loudnorm + alimiter) is ported below with the
# same settings, so quiet/loud recordings still come out consistent and just under
# clipping even without the voice-isolation step ahead of it.
class AudioProcessingService
  class FfmpegError < StandardError; end

  # Matches WhisperTranscriber's expected input in the original, and is a broadly
  # supported format for the hosted transcription API this rewrite calls instead.
  OUTPUT_SAMPLE_RATE = 16_000

  # `input_path` is any audio file ffmpeg can read (format is auto-detected from file
  # contents, not the extension -- same as the original). Returns the path to a new,
  # normalized 16kHz mono WAV file; the caller is responsible for deleting both files
  # when it's done with them.
  def self.normalize(input_path)
    new(input_path).normalize
  end

  def initialize(input_path)
    @input_path = input_path
  end

  def normalize
    # A random suffix, not just "#{@input_path}.normalized.wav" -- two uploads
    # processed at the same time (real concurrent requests, or the parallel test
    # suite reusing the same fixture file) would otherwise both try to write, then
    # delete, the exact same output path and step on each other.
    output_path = "#{@input_path}.#{SecureRandom.hex(8)}.normalized.wav"

    # loudnorm measures overall integrated loudness (not just momentary peaks), so a
    # recording that's quiet throughout gets boosted consistently rather than being
    # judged "loud enough" by one stray loud moment. alimiter is a hard safety net on
    # top, so the boosted signal never actually clips -- identical settings (I=-11,
    # TP=-0.3, LRA=7, limit=0.97) to what the original tuned and documented in
    # noise_reduction.py after testing plain speechnorm wasn't aggressive enough.
    run_ffmpeg([
      "-y", "-i", @input_path,
      "-af", "loudnorm=I=-11:TP=-0.3:LRA=7,alimiter=limit=0.97",
      "-ar", OUTPUT_SAMPLE_RATE.to_s, "-ac", "1",
      output_path
    ])

    output_path
  end

  # Pulls just the audio track out of a video file into a fresh 16-bit PCM WAV --
  # identical ffmpeg flags to the original's video.py, so a video upload feeds the
  # exact same downstream pipeline (normalize -> transcribe) as a plain audio upload.
  def self.extract_audio_from_video(video_path)
    # Same random-suffix reasoning as normalize() above.
    output_path = "#{video_path}.#{SecureRandom.hex(8)}.extracted.wav"
    new(video_path).send(:run_ffmpeg, [
      "-y", "-i", video_path,
      "-vn",                       # drop the video stream entirely, audio only
      "-acodec", "pcm_s16le",      # 16-bit PCM -- a safe, universally readable format
      "-ar", OUTPUT_SAMPLE_RATE.to_s, "-ac", "1",
      output_path
    ])
    output_path
  end

  private

  def run_ffmpeg(args)
    unless system("which ffmpeg > /dev/null 2>&1")
      raise FfmpegError, "ffmpeg not found on PATH -- install it (e.g. `brew install ffmpeg` on macOS, or apt-get install ffmpeg in the container)."
    end

    # capture3 hands back stdout, stderr, and the process status all at once, so a
    # failure can include ffmpeg's own error message instead of just "it failed."
    require "open3"
    _stdout, stderr, status = Open3.capture3("ffmpeg", *args)
    raise FfmpegError, "ffmpeg failed: #{stderr}" unless status.success?
  end
end

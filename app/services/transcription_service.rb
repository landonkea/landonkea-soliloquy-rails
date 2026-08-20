# ───────────────────────────────────────────────────────────────────
# TranscriptionService, audio file -> text
# ───────────────────────────────────────────────────────────────────
# HONEST DEVIATION FROM THE ORIGINAL, read this before changing anything here:
#
# The original Python app's transcriber.py used faster-whisper, a fully local speech-
# to-text model -- no audio ever left the device, which mattered specifically because
# this app can hold therapy-adjacent personal disclosure. Ruby has no mature,
# actively-maintained equivalent to faster-whisper (a local CTranslate2-backed Whisper
# implementation); there's nothing comparable in the Ruby gem ecosystem as of this
# rewrite, and embedding a multi-gigabyte PyTorch/CTranslate2 stack just to shell out
# to it from Ruby would make this "a Python app with a Rails skin," not a real Rails
# rewrite.
#
# So this service takes the other honest option the build brief allowed: it calls a
# hosted transcription API (OpenAI's Whisper endpoint by default, or any other service
# that speaks the same request/response shape -- Groq's Whisper endpoint is a drop-in
# swap, just change TRANSCRIPTION_API_URL) over HTTPS, using an API key from the
# environment. That is a real, meaningful privacy difference from the original: audio
# leaves the device and is sent to a third party. This is documented here, in
# .env.example, and in the README's "Transcription" section -- not hidden.
#
# The Transcriber-style single entry point (call) means swapping this out later for a
# real local-transcription approach (e.g. shelling out to a small Python
# faster-whisper subprocess, kept in its own virtualenv, per the build brief's other
# allowed option) would only mean rewriting this one class, not anything that calls it.
class TranscriptionService
  # Raised for anything that stops a real transcription from happening -- a missing
  # API key, a network failure, or a response shape that isn't recognized. Callers
  # should treat this as "transcription genuinely failed," never silently return an
  # empty string, since an empty transcript is indistinguishable from real silence.
  class TranscriptionError < StandardError; end

  # OpenAI's Whisper endpoint is the default target -- widely available, and enough
  # other providers (Groq, for one) mirror the exact same request shape that pointing
  # this at one of them is just an env var change.
  DEFAULT_API_URL = "https://api.openai.com/v1/audio/transcriptions"
  DEFAULT_MODEL = "whisper-1"

  # `audio_path` is a path to a local audio file on disk (already normalized to a
  # standard format by AudioProcessingService by the time this is called).
  def self.call(audio_path)
    new(audio_path).call
  end

  def initialize(audio_path)
    @audio_path = audio_path
  end

  def call
    api_key = ENV["TRANSCRIPTION_API_KEY"]
    raise TranscriptionError, "TRANSCRIPTION_API_KEY is not set -- see .env.example." if api_key.blank?

    response = connection.post do |request|
      request.headers["Authorization"] = "Bearer #{api_key}"
      # Faraday::Multipart::FilePart streams the audio file as a real multipart/form-
      # data upload, the same shape curl -F "file=@..." would send, and what OpenAI's
      # (and Groq's) transcription endpoint expects.
      request.body = {
        file: Faraday::Multipart::FilePart.new(@audio_path, "audio/wav"),
        model: ENV.fetch("TRANSCRIPTION_MODEL", DEFAULT_MODEL)
      }
    end

    unless response.success?
      raise TranscriptionError, "Transcription API returned #{response.status}: #{response.body}"
    end

    extract_text(response.body)
  end

  private

  def connection
    Faraday.new(url: ENV.fetch("TRANSCRIPTION_API_URL", DEFAULT_API_URL)) do |builder|
      builder.request :multipart
      builder.response :json, content_type: /\bjson$/
      builder.adapter Faraday.default_adapter
    end
  end

  # OpenAI (and Groq, mirroring it) return {"text": "..."} as plain JSON -- pulled out
  # as its own method so a provider with a slightly different response shape only
  # needs this one method overridden/changed, not the whole request flow.
  def extract_text(body)
    text = body.is_a?(Hash) ? body["text"] : nil
    raise TranscriptionError, "Unexpected transcription API response shape: #{body.inspect}" if text.nil?
    text
  end
end

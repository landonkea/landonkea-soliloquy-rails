# Soliloquy (Rails rewrite)

A voice-first journal: record a thought out loud, get it transcribed automatically, and see real AI analysis of what you've been thinking about — per day, per week, per month, over years.

**This is an independent, from-scratch rewrite. It is NOT connected to the real, live Soliloquy app in any way.** The original project this was rebuilt from — [`landonkea-soliloquy`](https://github.com/landonkea/landonkea-soliloquy) — is a real, actively-used personal journal with a real Postgres database and real audio recordings and journal entries in it. This repository has no access to that database, that object storage, or any real entry anyone has ever written. Running this code creates a brand-new, empty app on your own machine — it holds no real journal content from anyone, and it is not a way to view, access, or affect the original app or its data.

Separately, and unrelated to this rewrite entirely: the original app's *real* backend is in the middle of its own migration to a managed Postgres provider (Neon/Supabase). That's a completely different, ongoing effort. This rewrite has nothing to do with it, doesn't touch it, and was built without going anywhere near the original app's real infrastructure.

## What this app actually does

You say something out loud (or type it), it gets transcribed and cleaned up into readable text, and it's saved as one journal entry. Over time, you can ask for an AI-written summary of a stretch of entries — what's been on your mind, how your mood has been trending, what topics keep coming up — and export that as a report you could actually hand to a therapist.

## How the pieces fit together (plain English, file by file)

- **`app/models/entry.rb`** — one journal entry: the transcript, an optional audio/video file, tags, and two independent "share this with X" flags (partner and provider/therapist — kept separate on purpose, since what's fine to share with a partner and what's clinically useful for a therapist aren't the same thing). Every entry belongs to a `User`.
- **`app/models/user.rb` / `app/models/session.rb`** — your account. Built by Rails 8's own `bin/rails generate authentication` command, not hand-rolled — real bcrypt password hashing, real signed session cookies.
- **`app/models/analysis_snapshot.rb`** — a saved result from one AI analysis run, either one you asked for or one the background job ran automatically.
- **`app/models/saved_report.rb`** — a report you've chosen to keep, with an optional expiring link you can hand to someone who doesn't have an account here.
- **`app/services/`** — this is where the actual logic lives, not scattered across controllers:
  - `transcription_service.rb` — sends an audio file to a hosted transcription API and gets text back. See "Transcription" below — this is the one place this rewrite genuinely differs from the original in a way worth understanding before you rely on it.
  - `audio_processing_service.rb` — shells out to `ffmpeg` to normalize loudness (so quiet and loud recordings both come out clear) and, for video uploads, to pull just the audio track out.
  - `transcript_cleanup_service.rb` — a plain rule-based pass (capitalize sentences, add punctuation, break into paragraphs) that makes raw transcription output readable. No AI involved — this is deterministic, instant, and free.
  - `audio_entry_creation_service.rb` / `video_entry_creation_service.rb` — the real pipelines: upload → normalize → transcribe → clean up → save, with the file actually attached via Active Storage.
  - `analyzer_service.rb` + `app/services/analyzers/` — calls an AI provider (Claude, or a chain of free models via OpenRouter/Gemini) to turn a batch of entries into a summary, mood notes, a rough 1–10 mood score, and key topics.
  - `entry_report_service.rb` — the shared "which entries, over what range, filtered for which audience" logic every entry point (a controller, a background job, the MQTT bridge) uses, so a browser-triggered report and an automatic one always follow the same rules.
  - `entry_creation_service.rb` — the shared "save a new entry" logic, used by both the typed-entry form and the MQTT voice bridge.
  - `mqtt_bridge_service.rb` — turns an MQTT message into a journal entry (see "MQTT bridge" below).
  - `report_renderer.rb` + `report_content.rb` — turns an analysis result into a downloadable report in plain text, Markdown, HTML, or PDF (via the `prawn` gem).
  - `mood_chart_service.rb` — draws a small inline SVG line chart of mood over time. No JavaScript charting library — it's a server-rendered string, same as the original.
  - `journal_prompts.rb` / `journal_tips.rb` — the same 116 hand-written journaling prompts and 40 encouraging, practical tips from the original, ported over word for word, rotated one per day.
- **`app/controllers/`** — thin. Every controller mostly just calls a service object and renders a page; none of the real decision-making lives here.
- **`app/jobs/`** — `AnalysisJob`, `MonthlyReportJob`, and `MediaRetentionJob`, run on a schedule by Rails 8's built-in Solid Queue (see `config/recurring.yml`) — no separate scheduler library needed, unlike the original's use of APScheduler.
- **`bin/mqtt_listener`** — a separate, long-running process for the MQTT voice bridge (see below). Not started automatically with the web server.

## Transcription — the honest part

The original Python app used `faster-whisper`, a fully local speech-to-text model — no audio ever left the device, which mattered because this app can hold genuinely personal, sometimes therapy-adjacent disclosure. **Ruby has no mature, actively-maintained equivalent to `faster-whisper`.** There is nothing comparable in the Ruby gem ecosystem as of this rewrite, and bundling a multi-gigabyte PyTorch/CTranslate2 stack just to shell out to it from Ruby would make this "a Python app wearing a Rails costume," not a real Rails rewrite.

So `TranscriptionService` calls a **hosted transcription API** instead (OpenAI's Whisper endpoint by default — any provider speaking the same request/response shape, like Groq's Whisper-compatible endpoint, is a one-line config change). **This is a real, meaningful step down from the original's privacy model: your audio leaves your device and is sent to a third party.** That's stated here plainly, in `.env.example`, and in `TranscriptionService`'s own comments — not hidden. If you want to change this later, the whole point of the `TranscriptionService` interface is that swapping it out (for example, shelling out to a small local `faster-whisper` Python subprocess kept in its own virtualenv) means rewriting one class, not anything that calls it.

Also not reproduced from the original: **DeepFilterNet3**, a neural network the original used to isolate speech from background noise (wind, a dog barking, etc.) before transcription. That's a PyTorch model with no Ruby equivalent either. What *is* kept from the original: the ffmpeg loudness-normalization pass (`loudnorm` + `alimiter`, same settings), which still makes quiet/loud recordings come out consistent — just without the neural noise-isolation step ahead of it.

## AI analysis

Faithfully ported from the original's `analyzer.py`: the exact same prompt, asking for the same JSON shape back (`summary`, `mood_notes`, `mood_score`, `key_topics`), against the same three providers (Claude, OpenRouter, Gemini) with the same "free by default" chain — it tries OpenRouter's free-tagged models first, then falls back to Gemini's free tier, so running analysis costs nothing unless you explicitly set `ANALYZER_PROVIDER=claude`.

## Mood chart & PDF reports

The mood chart is a small hand-drawn inline SVG (`MoodChartService`), same approach as the original — no charting library needed for one line and a few dots. PDF reports use `prawn`, the Ruby equivalent of the original's `fpdf2`.

## MQTT bridge

Pairs with `landonkea-makeItSoNumberOne`'s `journal_entry` plugin, exactly like the original: say "Computer, journal entry: ..." and it lands here as a real entry, going through the same `EntryCreationService` a browser-typed entry uses. Run it as its own process:

```bash
bin/mqtt_listener
```

It needs an MQTT broker reachable at `$MQTT_HOST:$MQTT_PORT` (a local Mosquitto container works fine — see `.env.example`) and at least one signed-up user account, since entries need an owner and MQTT messages carry no login of their own.

## Running this yourself

You'll need Ruby 3.4.9 and no separate database server for local development — SQLite ships as a file alongside the app, matching this project's other Rails rewrites (the original used Postgres; this rewrite is a standalone app with its own data, so SQLite is the right fit here).

```bash
bundle install
bin/rails db:prepare
bin/rails dev:cache # optional
bin/dev              # starts the web server, Tailwind watcher, and background jobs together
```

Then open `http://localhost:3000` and create an account from the sign-up page — everything in this app requires being logged in.

### Environment variables

Copy `.env.example` to `.env` and fill in whichever of these you actually want to use. The app runs with zero configuration for local development — transcription and AI analysis will show a clear error message (not a fake result) until you add real API keys; everything else works immediately with local disk storage and SQLite.

- `TRANSCRIPTION_API_KEY` / `TRANSCRIPTION_API_URL` / `TRANSCRIPTION_MODEL` — see "Transcription" above.
- `ANALYZER_PROVIDER`, `OPENROUTER_API_KEY`, `GEMINI_API_KEY`, `ANTHROPIC_API_KEY` — see "AI analysis" above.
- `S3_ACCESS_KEY` / `S3_SECRET_KEY` / `S3_BUCKET` / `S3_REGION` / `S3_ENDPOINT_URL` — only used in production; local dev/test always use plain disk storage (see `config/storage.yml`). Works with real AWS S3, self-hosted MinIO, or Cloudflare R2, same as the original's `boto3`-based object storage.
- `MQTT_HOST` / `MQTT_PORT` / `MQTT_TOPIC` — see "MQTT bridge" above.
- `MEDIA_RETENTION_DAYS` — optional: auto-delete audio/video (never the transcript) once an entry passes this age.
- `SOLID_QUEUE_IN_PUMA` — set to `true` in production so the recurring background jobs run inside the same container as the web server.

### Running the tests

```bash
bin/rails db:test:prepare
bin/rails test
```

118 tests, all green — models, the auth/registration flow, every service object (transcription and every AI provider are tested against stubbed HTTP responses via WebMock, never a real network call), the real audio-processing pipeline (using small synthetic `ffmpeg`-generated test files, not mocks — `AudioProcessingService` and both entry-creation services genuinely shell out to `ffmpeg`), the background jobs, and every controller.

### Docker

```bash
docker build -t landonkea-soliloquy-rails .
docker run -d -p 3000:80 -e RAILS_MASTER_KEY=$(cat config/master.key) landonkea-soliloquy-rails
```

The Dockerfile is Rails 8's own generated one, with `ffmpeg` added as a system dependency (needed by `AudioProcessingService`) — confirmed to actually build and run: `/up` returns 200, and the app correctly redirects a signed-out visitor to the login page.

## What didn't make it into this rewrite

- **Local, fully private transcription** (see "Transcription" above) — the single biggest honest gap versus the original.
- **DeepFilterNet neural voice isolation** (see above) — ffmpeg loudness normalization is kept; the neural noise-removal step ahead of it isn't.
- **Postgres full-text search** — the original used `tsvector`/`plainto_tsquery`; SQLite has no equivalent enabled by default, so search here is a simpler `LIKE`-based substring match (won't match "running" when you search "run" the way real full-text search does).
- **Transcript encryption at rest** — the original had an opt-in Fernet-encrypted transcript column. Rails has a real built-in equivalent (Active Record Encryption, `bin/rails db:encryption:init`) that could be wired in the same "off by default" way, but it wasn't turned on here to keep this build's scope focused — a genuine, straightforward follow-up if you want it.
- A password gate is not needed here the way the original had one, since this rewrite uses real per-user accounts (Rails 8's built-in authentication) instead of a single shared password.

Everything else — entries, tags, search, "on this day," a journaling streak line, sharing flags with audience-filtered reports, daily rotating prompts and tips, the automatic background analysis job, the monthly scheduled report, saved reports with expiring share links, the MQTT bridge — is real and working, not a stub.

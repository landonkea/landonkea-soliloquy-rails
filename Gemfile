source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 2.1"

# Active Storage's S3 service (config/storage.yml) needs this to talk to S3-compatible
# object storage (MinIO, Cloudflare R2, real AWS S3) -- same boto3-does-S3-natively idea
# the original Python app relied on, just Ruby's version of that client.
gem "aws-sdk-s3", require: false

# Loads variables from a local .env file in development/test so nobody has to export
# API keys by hand every time they open a new terminal -- production reads real
# environment variables instead (see config/application.rb).
gem "dotenv-rails", groups: [ :development, :test ]

# HTTP client used by the transcription service and the AI analysis service to talk to
# whichever provider is configured (OpenAI-compatible transcription API, Claude,
# OpenRouter, Gemini) -- the same "one HTTP layer, several providers" shape the
# original's analyzer.py used with the `requests` library.
gem "faraday"
gem "faraday-multipart" # lets Faraday send a real multipart/form-data audio upload

# Talks to the Mosquitto MQTT broker for the voice-journal bridge (mirrors the
# original's mqtt_bridge.py, which used the Python `paho-mqtt` package).
gem "mqtt"

# Generates the PDF report export -- the Ruby equivalent of the original's fpdf2.
gem "prawn"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # Intercepts outbound HTTP calls in tests so the transcription/analysis services can
  # be tested against fake, fast, canned responses instead of real (and costly) network
  # calls to OpenAI/Claude/OpenRouter/Gemini.
  gem "webmock"

  # Minitest 6 split object mocking (Minitest::Mock) out into its own gem -- needed by
  # the FallbackAnalyzer tests, which use a mock provider to prove "the next provider
  # only gets tried after the first one fails" without making any real HTTP call.
  gem "minitest-mock"
end

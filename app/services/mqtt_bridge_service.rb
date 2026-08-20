# ───────────────────────────────────────────────────────────────────
# MqttBridgeService, turns MQTT messages into journal entries (and back)
# ───────────────────────────────────────────────────────────────────
# Direct port of the original's mqtt_bridge.py -- the Soliloquy side of the
# voice-triggered entry pipeline: landonkea-makeItSoNumberOne's `journal_entry` plugin
# publishes a JSON message on $MQTT_TOPIC when it hears "Computer, journal entry:
# ..."; this class turns that into a real Entry via EntryCreationService.add/
# append_or_add -- the exact same service the web app's typed-entry form uses, so a
# voice-triggered entry and a browser-typed one go through identical rules.
#
# This class is pulled apart from the actual MQTT network connection (see
# bin/mqtt_listener, which owns the real paho-style client loop) specifically so the
# message-handling logic can be unit tested by calling handle_write/handle_query
# directly with a plain payload string, no real broker needed -- same reasoning the
# original's own handle_message/handle_query being separate, directly-testable
# functions gave.
#
# Payload shape for the write topic:
#   {"text": "...", "type": "new"}     -- default, same as before
#   {"text": "...", "type": "append"}  -- appends to the most recent entry from today
#                                          if one exists within the last hour with the
#                                          same speaker (see EntryCreationService.append_or_add)
#   {"speaker": "Landon", ...}          -- optional, see entry.rb's docstring on
#                                          multi-speaker households
class MqttBridgeService
  DEFAULT_QUERY_DAYS = 7

  WriteOutcome = Struct.new(:entry, :appended, :error, keyword_init: true)

  # Turns one write-topic MQTT payload into a saved (or appended-to) Entry, for the
  # given `user` (the journal this bridge is writing into -- see bin/mqtt_listener for
  # how that gets picked, since MQTT messages carry no login of their own).
  def self.handle_write(payload, user:)
    data = JSON.parse(payload)
    unless data.is_a?(Hash)
      Rails.logger.warn("Ignoring MQTT message that isn't a JSON object: #{data.inspect}")
      return WriteOutcome.new(entry: nil, appended: false, error: "message must be a JSON object")
    end

    text = data["text"].to_s.strip
    if text.blank?
      Rails.logger.warn("Ignoring MQTT message with no usable \"text\": #{data.inspect}")
      return WriteOutcome.new(entry: nil, appended: false, error: "message had no usable \"text\"")
    end

    speaker = data["speaker"].presence
    message_type = data["type"] || "new"

    entry, appended =
      if message_type == "append"
        EntryCreationService.append_or_add(user: user, text: text, speaker: speaker)
      else
        [ EntryCreationService.add(user: user, transcript: text, speaker: speaker), false ]
      end

    Rails.logger.info("#{appended ? 'Appended to' : 'Saved'} entry #{entry.id} from MQTT (#{entry.word_count} words).")
    WriteOutcome.new(entry: entry, appended: appended, error: nil)
  rescue JSON::ParserError
    Rails.logger.warn("Ignoring non-JSON MQTT message: #{payload.inspect}")
    WriteOutcome.new(entry: nil, appended: false, error: "message wasn't valid JSON")
  end

  # "What have I been journaling about lately" as a spoken question. Payload:
  # {"days": 7} (defaults to DEFAULT_QUERY_DAYS if omitted/unparseable). Returns a
  # plain hash (what gets JSON-published back on $MQTT_TOPIC/query/response), or nil
  # if there's nothing to say -- logged either way, never raised, same reasoning as
  # handle_write: a bad query shouldn't crash the listener.
  def self.handle_query(payload, user:, analyzer: AnalyzerService.default_analyzer)
    data = JSON.parse(payload) rescue {}
    days = data.is_a?(Hash) ? data["days"].to_i : 0
    days = DEFAULT_QUERY_DAYS if days <= 0

    begin
      result = EntryReportService.analyze_range(user: user, analyzer: analyzer, days: days)
    rescue Analyzers::NoEntriesError
      Rails.logger.info("MQTT query: no entries in the last #{days} day(s).")
      return nil
    rescue RuntimeError => e
      Rails.logger.warn("MQTT query failed: #{e.message}")
      return nil
    end

    { days: days, entry_count: result.entry_count, summary: result.summary, mood_notes: result.mood_notes, key_topics: result.key_topics }
  end
end

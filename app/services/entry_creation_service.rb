# ───────────────────────────────────────────────────────────────────
# EntryCreationService, the shared "write a journal entry" logic
# ───────────────────────────────────────────────────────────────────
# Both the web app's typed-entry form and the MQTT voice bridge end up creating an
# entry through this one service, the same way the original's actions.add_entry/
# append_or_add_entry were shared by cli.py, web/app.py, and mqtt_bridge.py. Keeping
# this logic in one place is what keeps a voice-triggered entry and a browser-typed
# one behaving identically instead of drifting into two sets of rules.
class EntryCreationService
  def self.add(user:, transcript:, tags: [], speaker: nil)
    user.entries.create!(transcript: transcript, tags: tags, speaker: speaker)
  end

  # Used by the MQTT bridge's "append to today" message type -- "also I forgot to
  # mention..." a minute after a voice entry should land on the SAME entry, not a
  # second, disconnected one. Appends to the most recent entry from today if one
  # exists within the last `within_minutes` minutes AND has the same speaker (or
  # neither has a speaker set); otherwise creates a brand new entry. Returns
  # [entry, appended] just like the original's append_or_add_entry.
  def self.append_or_add(user:, text:, speaker: nil, within_minutes: 60)
    today_entries = user.entries.range_between(Time.current.beginning_of_day, Time.current).order(:created_at)

    if today_entries.any?
      latest = today_entries.last
      age = Time.current - latest.created_at
      if age <= within_minutes.minutes && latest.speaker == speaker
        latest.update!(transcript: "#{latest.transcript} #{text}".strip)
        return [ latest, true ]
      end
    end

    [ add(user: user, transcript: text, speaker: speaker), false ]
  end
end

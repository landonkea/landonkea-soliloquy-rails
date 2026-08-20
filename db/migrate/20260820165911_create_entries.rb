# This migration builds the "entries" table -- one row per journal entry, the single
# most important table in the whole app (everything else, analysis, reports, mood
# charts, is derived from what's in here). It mirrors the original Python app's
# EntryStore schema (src/soliloquy/storage.py) column-for-column, translated from
# Postgres types to their closest SQLite/Rails equivalents.
class CreateEntries < ActiveRecord::Migration[8.1]
  def change
    # create_table wraps every t.* line below into one CREATE TABLE statement.
    create_table :entries do |t|
      # The actual words the person said (or typed) -- required, an entry with no
      # transcript isn't a journal entry at all. null: false enforces that at the
      # database level, not just in a Rails validation, so it can never sneak past
      # some future code path that skips model validations.
      t.text :transcript, null: false

      # Two independent sharing flags, not one "privacy level" -- see entry.rb for the
      # full reasoning (ported straight from the original's entry.py docstring). Both
      # default to false so every entry is private until someone explicitly opts it in.
      t.boolean :shareable_with_partner, null: false, default: false
      t.boolean :shareable_with_provider, null: false, default: false

      # Freeform topic labels ("work", "family") the person or the analysis can attach.
      # Stored as a JSON array in one column (SQLite has no native array type the way
      # Postgres does) -- default: [] means a brand new entry always has a real empty
      # array to work with, never nil.
      t.json :tags, null: false, default: []

      # Who said this, for a household with more than one journaler sharing the same
      # MQTT bridge -- nil means "unknown/not applicable" (the normal case for
      # anything typed through the web UI).
      t.string :speaker

      # Every entry belongs to the person who owns this journal. foreign_key: true adds
      # a real database-level constraint so an entry can never point at a user row that
      # doesn't exist.
      t.references :user, null: false, foreign_key: true

      # created_at/updated_at, added automatically by Rails -- created_at is what
      # range_between-style day/week/month queries filter on below.
      t.timestamps
    end

    # Speeds up "entries in this date range" queries (the building block for per-day/
    # week/month analysis) and keeps newest-first listings fast as the table grows --
    # the same index the original's SCHEMA constant created on created_at.
    add_index :entries, :created_at
  end
end

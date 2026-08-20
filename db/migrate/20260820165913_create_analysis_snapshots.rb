# "analysis_snapshots" holds saved results from past AI analysis runs -- both the ones
# a person triggers by hand and the ones the background job runs on a timer. This
# mirrors analysis_store.py's table from the original almost exactly; the snapshot is a
# disposable, derived summary (could be regenerated from the same entries any time),
# not permanent user-authored content the way an Entry is.
class CreateAnalysisSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_snapshots do |t|
      # How many days back this snapshot looked (1 for the routine background run, 7/30
      # for a manually requested week/month view).
      t.integer :days, null: false

      # Which audience this was generated for -- "self", "partner", or "provider". The
      # background job only ever writes "self" (see the original's scheduler.py
      # comment on why auto-generating a shareable summary would be a bad default).
      t.string :audience, null: false

      # How many entries and words went into this snapshot -- shown on the Analysis
      # page so "this covers 4 entries" is visible without recomputing anything.
      t.integer :entry_count, null: false
      t.integer :total_word_count, null: false

      # The actual AI-written text: an honest summary, and separately, notes specifically
      # about emotional tone/trends.
      t.text :summary, null: false
      t.text :mood_notes, null: false

      # A short list of recurring themes the model noticed, stored as a JSON array of
      # strings.
      t.json :key_topics, null: false, default: []

      # 1-10, the model's own rough read of overall mood -- nullable, because not every
      # provider reliably returns one, and a missing data point should just be skipped
      # on the mood chart, never faked as a real number.
      t.integer :mood_score

      # Every snapshot belongs to the journal owner it was generated for.
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    # The Analysis page always wants "the most recent ones first" -- this index makes
    # that ORDER BY created_at DESC cheap even once there are years of snapshots.
    add_index :analysis_snapshots, :created_at
  end
end

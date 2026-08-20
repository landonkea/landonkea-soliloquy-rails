# A saved result from one run of AI analysis -- either the background job's routine
# check-in or a report a person asked for by hand. See db/migrate/*_create_analysis_
# snapshots.rb for what each column holds; this class mostly just adds the query
# helpers the Analysis page needs.
class AnalysisSnapshot < ApplicationRecord
  belongs_to :user

  # The Analysis page and the mood chart both want "most recent first" -- this scope
  # is the one place that ordering is defined, matching AnalysisSnapshotStore.recent()
  # from the original.
  scope :recent, ->(limit = 10) { order(created_at: :desc).limit(limit) }

  # Only the snapshots that got a real mood_score back -- a provider that skipped the
  # field (see AnalysisService) shouldn't leave a fake data point on the chart.
  scope :scored, -> { where.not(mood_score: nil) }
end

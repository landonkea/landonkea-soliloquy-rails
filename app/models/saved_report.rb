# A report someone chose to keep -- see db/migrate/*_create_saved_reports.rb for the
# columns. The interesting part of this class is the share-link logic: Rails' built-in
# `signed_id` does exactly what the original's report_store.py hand-rolled with the
# itsdangerous library (a tamper-proof, time-limited token that resolves back to one
# specific row), so there's no custom signing code needed here at all.
class SavedReport < ApplicationRecord
  belongs_to :user

  scope :recent, ->(limit = 20) { order(created_at: :desc).limit(limit) }

  # How long a share link stays valid by default -- same 7 days the original used
  # (report_store.py's DEFAULT_SHARE_LINK_DAYS).
  DEFAULT_SHARE_LINK_EXPIRY = 7.days

  # A purpose string namespaces this signed id from any other signed id this app might
  # ever generate (e.g. Active Storage's own signed URLs), the same reason the original
  # passed a distinct `salt` to itsdangerous -- so a share link token could never be
  # confused for, or reused as, some other kind of signed token even though they'd both
  # ultimately be signed with the same underlying Rails secret.
  SHARE_LINK_PURPOSE = "saved_report_share_link"

  # Builds a signed, expiring token for this report. Handing this to `SavedReport.find_signed`
  # (Rails' own method, not custom code) later returns this exact record, or nil if the
  # token was tampered with or has expired -- the direct equivalent of the original's
  # make_share_token/resolve_share_token pair.
  def share_token(expires_in: DEFAULT_SHARE_LINK_EXPIRY)
    signed_id(expires_in: expires_in, purpose: SHARE_LINK_PURPOSE)
  end
end

# Resolves a signed share-link token back to a real SavedReport, with NO login
# required -- deliberately outside the normal authenticated area, since the entire
# point of a share link is handing it to someone (a therapist, a partner) who doesn't
# have, and shouldn't need, an account here. The signed, expiring token itself is the
# only access control this route has, matching the original's shared_report route and
# its comment on why AuthMiddleware exempted it.
class SharedReportsController < ApplicationController
  allow_unauthenticated_access

  def show
    # find_signed returns nil for a tampered-with OR expired token -- deliberately not
    # distinguished from each other here, so a guessed/altered token gets the same
    # generic "invalid or expired" response either way, same reasoning the original's
    # resolve_share_token documented.
    @report = SavedReport.find_signed(params[:token], purpose: SavedReport::SHARE_LINK_PURPOSE)
    unless @report
      render plain: "This share link is invalid or has expired.", status: :not_found
    end
  end
end

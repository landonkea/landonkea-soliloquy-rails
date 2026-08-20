# ───────────────────────────────────────────────────────────────────
# EntriesController, the Entries (home) page + all the ways to create/edit one
# ───────────────────────────────────────────────────────────────────
# Mirrors the original web/app.py's entries_page/new_entry_page/post_entry/
# post_audio_entry/post_video_entry/share_entry/update_tags/update_transcript/
# delete_entry all in one place -- this controller doesn't hold real business logic
# itself, it calls the service objects (EntryCreationService, AudioEntryCreationService,
# VideoEntryCreationService) the same way the original's routes called actions.py's
# functions, so a future API client would reuse the exact same services.
class EntriesController < ApplicationController
  before_action :set_entry, only: [ :edit, :update, :destroy ]

  def index
    query = params[:q].to_s.strip
    tag = params[:tag].to_s.strip

    @entries =
      if query.present?
        Current.user.entries.search_transcripts(query)
      elsif tag.present?
        Current.user.entries.by_tag(tag)
      else
        Current.user.entries.order(created_at: :desc)
      end

    @query = query
    @selected_tag = tag
    @all_tags = Current.user.entries.all_tags
    @tip = JournalTips.for_today

    # "On this day" and the streak line describe the whole journal, not a filtered
    # search result -- showing them underneath a search wouldn't make sense, so both
    # are only computed for the unfiltered view, same condition the original used.
    @on_this_day_entries = (query.blank? && tag.blank?) ? EntryReportService.on_this_day(user: Current.user) : []
    @journaled_days, @streak_window = EntryReportService.journaling_streak(user: Current.user)
  end

  def new
    @prompt = JournalPrompts.for_today
  end

  # Typed (text-only) entries -- no transcription pipeline needed, the person already
  # wrote exactly what they meant.
  def create
    entry = EntryCreationService.add(user: Current.user, transcript: params[:transcript].to_s)
    redirect_to root_path, notice: entry.persisted? ? "Entry saved." : "Could not save entry."
  end

  def create_audio
    if params[:audio_file].blank?
      redirect_to new_entry_path, alert: "Choose an audio file to upload." and return
    end
    AudioEntryCreationService.call(user: Current.user, uploaded_file: params[:audio_file])
    redirect_to root_path, notice: "Entry transcribed and saved."
  rescue TranscriptionService::TranscriptionError, AudioProcessingService::FfmpegError => e
    redirect_to new_entry_path, alert: "Could not process that recording: #{e.message}"
  end

  def create_video
    if params[:video_file].blank?
      redirect_to new_entry_path, alert: "Choose a video file to upload." and return
    end
    VideoEntryCreationService.call(user: Current.user, uploaded_file: params[:video_file])
    redirect_to root_path, notice: "Entry transcribed and saved."
  rescue VideoEntryCreationService::ExtractionError, TranscriptionService::TranscriptionError, AudioProcessingService::FfmpegError => e
    redirect_to new_entry_path, alert: "Could not process that video: #{e.message}"
  end

  # One update action handles every kind of in-place edit the Entries page offers --
  # toggling either sharing flag, editing tags, or correcting the transcript text --
  # since they're all "change one field on an existing entry" and Rails' strong
  # parameters already only apply whichever of these the submitted form actually sent.
  def update
    @entry.update!(entry_update_params)
    redirect_to root_path, notice: "Entry updated."
  end

  def destroy
    @entry.destroy!
    redirect_to root_path, notice: "Entry deleted."
  end

  private

  def set_entry
    @entry = Current.user.entries.find(params[:id])
  end

  def entry_update_params
    permitted = params.permit(:shareable_with_partner, :shareable_with_provider, :transcript, :tags)
    # The tags field arrives as one comma-separated string from a plain text input (no
    # separate tag-picker widget) -- split/trim it into a real array here, same as the
    # original's update_tags route did server-side rather than pushing that parsing
    # into JavaScript.
    permitted[:tags] = permitted[:tags].split(",").map(&:strip).reject(&:blank?) if permitted[:tags]
    permitted
  end
end

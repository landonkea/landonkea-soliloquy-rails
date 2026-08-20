Rails.application.routes.draw do
  # Rails 8's built-in authentication generator already wired these two up: a session
  # (login/logout) and a password-reset flow. Nothing custom needed for either.
  resource :session
  resources :passwords, param: :token

  # The generator doesn't scaffold a sign-up page (it assumes accounts are created
  # some other way) -- this app needs one, since it's meant to be self-service for
  # whoever's running it, so RegistrationsController below adds it.
  resource :registration, only: [ :new, :create ], controller: "registrations"

  # The Entries page is the home page -- everything else branches off from "here's
  # what I've journaled," same as the original's entries_page being mounted at "/".
  root "entries#index"

  resources :entries, only: [ :index, :new, :create, :edit, :update, :destroy ] do
    collection do
      # Two more entry-creation paths beyond the default typed-text `create` above --
      # kept as their own routes/actions (not one giant branching action) because
      # each has a genuinely different pipeline behind it (see AudioEntryCreationService/
      # VideoEntryCreationService), matching the original's separate
      # /entries + /entries/audio + /entries/video routes.
      post :audio, to: "entries#create_audio"
      post :video, to: "entries#create_video"
    end
  end

  # The Report page: a form to pick a day range/audience/format, and the POST that
  # actually runs analysis and streams a downloadable file back -- same shape as the
  # original's GET /report + POST /reports pair.
  get "report", to: "reports#new"
  post "report", to: "reports#create"

  # The Analysis page reads whatever the background job (or a person) has already
  # saved as AnalysisSnapshots -- no form, just a page.
  get "analysis", to: "analyses#show"

  # Saved reports (kept for later reference/sharing) and their expiring, signed public
  # share links -- mirrors the original's /reports/saved, /reports/save, and
  # /reports/shared/{token} routes.
  get "reports/saved", to: "saved_reports#index"
  post "reports/saved", to: "saved_reports#create"
  post "reports/saved/:id/share_link", to: "saved_reports#share_link", as: :saved_report_share_link
  # Deliberately its own controller/route, outside the authenticated area (see
  # SharedReportsController) -- the whole point of a share link is letting someone
  # with no account here view it.
  get "reports/shared/:token", to: "shared_reports#show", as: :shared_report

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end

Rails.application.routes.draw do
  # Load balancers and uptime monitors use this to check the app booted.
  get "up" => "rails/health#show", as: :rails_health_check

  # Admin status page (basic auth with STATUS_USERNAME / STATUS_PASSWORD).
  get "status" => "status#show", as: :status

  resource :session, only: %i[ new create destroy ]
  resource :registration, only: %i[ new create ]
  resources :passwords, param: :token, only: %i[ new create edit update ]
  resources :email_confirmations, param: :token, only: %i[ new create show ]
  resource :account, only: %i[ show update ]
  resource :reminder_settings, only: :update

  resources :tenders, only: %i[ index show ] do
    # Documents and items, loaded into the tender page by a lazy Turbo Frame.
    get :details, on: :member
    # "Acompanhar" button. GET only sends signed-out users back to the tender after login.
    resource :watch, only: %i[ show create destroy ] do
      # Private note of a watched tender, edited inline (Turbo Frame).
      resource :note, only: %i[ show edit update ], module: :watches
    end
  end
  # "Minhas licitações": the watched tenders.
  resources :watches, only: :index, path: "minhas-licitacoes"
  # Secret iCalendar feed of the watched deadlines, and the button that replaces its token.
  get "calendario/:token.ics" => "calendar_feeds#show", as: :calendar_feed, format: false
  resource :calendar_token, only: :create
  resources :saved_searches, except: :show
  resources :api_tokens, only: %i[ index create destroy ]

  # Unsubscribe links of the daily digest (signed token, no login).
  get "unsubscribe/:token" => "unsubscribes#show", as: :unsubscribe
  post "unsubscribe/:token" => "unsubscribes#create"

  # JSON API (docs/API.md), bearer-token authentication.
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :tenders, only: %i[ index show ]
      resources :saved_searches, only: %i[ index show create destroy ]
      resources :watches, only: %i[ index create destroy ]
    end
  end

  root "pages#home"
end

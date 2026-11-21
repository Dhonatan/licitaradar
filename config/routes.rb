Rails.application.routes.draw do
  # Load balancers and uptime monitors use this to check the app booted.
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session, only: %i[ new create destroy ]
  resource :registration, only: %i[ new create ]
  resources :passwords, param: :token, only: %i[ new create edit update ]

  resources :tenders, only: %i[ index show ]
  resources :saved_searches, except: :show
  resources :api_tokens, only: %i[ index create destroy ]

  # Unsubscribe links of the daily digest (signed token, no login).
  get "unsubscribe/:token" => "unsubscribes#show", as: :unsubscribe
  post "unsubscribe/:token" => "unsubscribes#create"

  root "pages#home"
end

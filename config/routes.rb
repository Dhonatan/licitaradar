Rails.application.routes.draw do
  # Load balancers and uptime monitors use this to check the app booted.
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session, only: %i[ new create destroy ]
  resources :passwords, param: :token, only: %i[ new create edit update ]

  resources :tenders, only: %i[ index show ]

  root "pages#home"
end

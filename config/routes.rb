Rails.application.routes.draw do
  # Load balancers and uptime monitors use this to check the app booted.
  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#home"
end

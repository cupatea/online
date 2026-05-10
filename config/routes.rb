Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resource  :setting, only: [ :show, :update ]
  resources :services, except: [ :show ]
  post "republish" => "services#republish", as: :republish

  root "services#index"
end

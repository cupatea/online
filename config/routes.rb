Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Public launcher, served at / on the dashboard port. The constraint matches
  # by which local port the request hit (DASHBOARD_PORT), and must precede the
  # admin `root` so it wins there. The before_action in ApplicationController is
  # what actually locks down the other admin routes on that port.
  get "/", to: "dashboard#index", as: :dashboard,
           constraints: ->(req) { ApplicationController.dashboard_request?(req) }

  resource  :setting, only: [ :show, :update ]
  resources :services, except: [ :show ]
  post "republish" => "services#republish", as: :republish

  root "services#index"
end

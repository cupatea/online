Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :admin do
    get    "login",  to: "sessions#new"
    post   "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy"
  end

  # Public launcher, served at / on the dashboard port. The constraint matches
  # by which local port the request hit (DASHBOARD_PORT), and must precede the
  # admin `root` so it wins there. The before_action in ApplicationController is
  # what actually locks down the other admin routes on that port.
  get "/", to: "dashboard#index", as: :dashboard,
           constraints: ->(req) { ApplicationController.dashboard_request?(req) }

  # Personal-link profiles (dashboard surface). Fixed paths first; the catch-all
  # ":slug" routes go last so they don't shadow /new, /setting, /services, etc.
  get  "new",      to: "profiles#new",    as: :new_profile
  post "profiles", to: "profiles#create", as: :profiles

  resource  :setting, only: [ :show, :update ]
  resources :services, except: [ :show ]
  post "republish" => "services#republish", as: :republish

  get    ":slug/edit",           to: "profiles#edit",   as: :edit_profile
  patch  ":slug",                to: "profiles#update"
  delete ":slug",                to: "profiles#destroy"
  get    ":slug/links",          to: "links#index",     as: :profile_links
  get    ":slug/links/new",      to: "links#new",       as: :new_profile_link
  post   ":slug/links",          to: "links#create"
  post   ":slug/links/reorder",  to: "links#reorder",   as: :reorder_profile_links
  get    ":slug/links/:id/edit", to: "links#edit",      as: :edit_profile_link
  patch  ":slug/links/:id",      to: "links#update",    as: :profile_link
  delete ":slug/links/:id",      to: "links#destroy"

  get    ":slug/categories",          to: "categories#index",   as: :profile_categories
  get    ":slug/categories/new",      to: "categories#new",     as: :new_profile_category
  post   ":slug/categories",          to: "categories#create"
  post   ":slug/categories/reorder",  to: "categories#reorder", as: :reorder_profile_categories
  get    ":slug/categories/:id/edit", to: "categories#edit",    as: :edit_profile_category
  patch  ":slug/categories/:id",      to: "categories#update",  as: :profile_category
  delete ":slug/categories/:id",      to: "categories#destroy"
  get    ":slug",                to: "profiles#show",   as: :profile

  root "services#index"
end

require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  mount Sidekiq::Web => "/sidekiq"

  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions",
    omniauth_callbacks: "users/omniauth_callbacks",
    confirmations: "users/confirmations"
  }

  root to: "top#index"

  resources :tasks do
    member do
      patch :complete
      post :log_amount
    end
  end

  resources :characters, only: [:index, :show] do
    collection do
      post :feed
      post :reset
    end
  end

  resource :charts, only: [:show]

  # Line通知設定画面用のルーティング追加
  resource :settings, only: [:show] do
    # Line設定の表示・編集・更新
    get "line", to: "settings#line_settings"
  end

  resource :profile, only: [:show]
  resource :rankings, only: [:show]

  # 新規登録後のたまご入手画面
  get "welcome/egg", to: "welcome#egg", as: :welcome_egg
  get "dashboard", to: "dashboard#show", as: :dashboard_show

  get "share/hatched/:character_id", to: "share#hatched", as: :share_hatched
  get "share/evolved/:character_id", to: "share#evolved", as: :share_evolved
  get "terms", to: "pages#terms", as: :terms
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  namespace :webhooks do
    post "line", to: "line#create"
  end
end

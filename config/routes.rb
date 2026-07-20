Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resource :session
  resource :registration, only: %i[new create]
  resources :passwords, param: :token

  namespace :webhooks do
    resource :whatsapp, only: %i[show create], controller: "whatsapp"
  end

  resource :dashboard, only: [ :show ]
  resources :integrations, only: [ :index ]
  namespace :integrations do
    resource :whatsapp, only: [], controller: "whatsapp" do
      post :connect
      delete :disconnect
    end
  end
  resources :transactions
  resources :customers
  resources :messages, only: [ :index ]

  root "dashboards#show"
end

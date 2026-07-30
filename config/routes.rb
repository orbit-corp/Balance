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
  resources :transactions do
    patch :post_to_books, on: :member
  end
  resources :accounts, only: %i[index update]
  resources :customers
  resources :messages, only: [ :index ]
  resources :document_reviews, only: [ :index ] do
    patch :dismiss, on: :member
  end
  resources :campaigns, only: %i[index new create show update] do
    resources :conversions, only: %i[create]
    resources :campaign_channels, only: %i[create], path: "channels" do
      resources :shortlinks, only: %i[create]
    end
  end

  root "dashboards#show"

  # Redirect engine — must stay last so it never shadows a named route above.
  get "/:slug", to: "redirects#show", constraints: { slug: /[a-z0-9-]+/ }
end

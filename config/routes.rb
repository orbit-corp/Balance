Rails.application.routes.draw do
  resources :models, only: [ :index, :show ], controller: "llm/models" do
    collection do
      post :refresh
    end
  end
  resources :chats, controller: "llm/chats", except: [ :new ], constraints: { id: /\d+/ } do
    resources :messages, only: [ :create ], controller: "llm/messages"
    resources :proposals, only: [ :update ], controller: "llm/proposals" do
      member do
        patch :confirm
        patch :dismiss
      end
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resource :session
  resource :registration, only: %i[new create]
  get "onboarding/:step", to: "onboarding#show", as: :onboarding_step
  patch "onboarding/:step", to: "onboarding#update"
  resources :passwords, param: :token

  resource :dashboard, only: [ :show ]
  resources :journal_entries, only: %i[index new create]
  resources :accounts, only: %i[index new create update]
  resources :customers

  root "dashboards#show"
end

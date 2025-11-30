Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  # Custom authentication routes for production
  devise_scope :user do
    get "/login", to: "users/sessions#new", as: :login
    post "/login", to: "users/sessions#create"
    get "/signup", to: "users/registrations#new", as: :signup
    post "/signup", to: "users/registrations#create"
    delete "/logout", to: "users/sessions#destroy", as: :logout
  end

  root "campaigns#index"

  # Profile completion routes
  get  "/complete-profile", to: "profiles#edit",   as: :complete_profile
  patch "/complete-profile", to: "profiles#update"

  resources :campaigns do
    resources :leads
  end

  namespace :api do
    namespace :v1 do
      resources :campaigns, only: [ :index, :create, :update, :destroy ] do
        member do
          post :send_emails
        end
        resources :agent_configs, only: [ :index, :show, :create, :update, :destroy ]
      end

      resources :leads, only: [ :index, :create, :update, :destroy ] do
        member do
          post :run_agents
          get :agent_outputs
          patch :update_agent_output
          post :send_email
        end
      end

      resource :api_keys, only: [ :show, :update ]
      resource :email_config, only: [ :show, :update ]
      resource :oauth_status, only: [ :show ]
    end
  end

  # OAuth routes for Gmail email sending
  get "/oauth/gmail/authorize", to: "oauth#gmail_authorize", as: :gmail_oauth_authorize
  get "/oauth/gmail/callback", to: "oauth#gmail_callback", as: :gmail_oauth_callback
  delete "/oauth/gmail/revoke", to: "oauth#gmail_revoke", as: :gmail_oauth_revoke

  # Silence Chrome DevTools probe in development
  if Rails.env.development?
    get "/.well-known/*path", to: ->(_) { [ 204, { "Content-Type" => "text/plain" }, [ "" ] ] }
  end
end

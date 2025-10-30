Rails.application.routes.draw do
  devise_for :users
  root 'campaigns#index'

  resources :campaigns do
    resources :leads
  end

  namespace :api do
    namespace :v1 do
      resources :campaigns, only: [:index, :create, :update, :destroy] do
        resources :agent_configs, only: [:index, :show, :create, :update, :destroy]
      end
      
      resources :leads, only: [:index, :create, :update, :destroy] do
        member do
          post :run_agents
          get :agent_outputs
          patch :update_agent_output
        end
      end
      
      resource :api_keys, only: [:show, :update]
    end
  end

  # Silence Chrome DevTools probe in development
  if Rails.env.development?
    get '/.well-known/*path', to: ->(_) { [204, { 'Content-Type' => 'text/plain' }, ['']] }
  end
end

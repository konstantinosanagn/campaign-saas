Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :campaigns, only: [:create]
      get 'campaigns/health', to: 'campaigns#health'
    end
  end

  # Root endpoint
  root 'api/v1/campaigns#health'
end

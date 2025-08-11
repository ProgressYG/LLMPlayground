Rails.application.routes.draw do
  # API routes
  namespace :api do
    resources :models, only: [:index, :show]
    resources :prompts, only: [] do
      collection do
        post :execute
      end
      member do
        get :status
        get :code
        get :export
      end
    end
    resources :templates
    get 'usage_history', to: 'usage_history#index'
  end
  
  # Main playground
  root "playground#index"
  get "playground/index"
  
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end

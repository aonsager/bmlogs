require 'resque/server'

Rails.application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'home#index'
  get 'logout' => 'home#logout'
  # get 'logs/:user' => 'logs#show'
  # get 'logs/:user/refresh' => 'logs#refresh'
  # get 'logs/import/:log_id' => 'logs#import', as: :import

  get 'about' => 'home#about'
  get 'checkmywow' => 'home#checkmywow'

  resources :users, only: [:show] do
    get 'refresh'

    resources :players, only: [:index]

  end

  resources :fights, only: [:show] do
    get 'load_hp_graph'
  end

  resources :players, only: [:show] do
    collection do
      get 'search'
    end
    resources :bosses, only: [] do
      get '/:difficulty' => 'bosses#show', as: :show
    end
  end

  resources :reports, only: [:show] do

    resources :fights, only: [] do

    end
  end

  resources :zones, only: [:index] do
    collection do 
      get 'refresh'
    end
  end
  
  if Rails.env.development?
    mount Resque::Server.new, at: "/resque"
  end

end

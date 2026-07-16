class InternalApi < ::Rails::Engine
end

InternalApi.routes.draw do
  namespace :api, defaults: { format: 'json' }, path: '' do
    scope module: :internal do
      post 'search' => 'search#search'
      get 'search' => 'search#search'
      get 'search_suggestions' => 'search#suggestions'

      resources :atars, only: %i[index show], param: :ref if TradeTariffBackend.uk?
    end
  end
end

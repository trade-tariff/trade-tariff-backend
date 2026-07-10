class V3Api < ::Rails::Engine
end

V3Api.routes.draw do
  namespace :api, defaults: { format: 'json' }, path: '/' do
    scope module: :v3 do
      resources :sections, only: %i[index show] do
        member { get :chapters }
      end

      resources :chapters, only: [:show], constraints: { id: /\d{1,2}/ } do
        member { get :headings }
      end

      resources :headings, only: [:show], constraints: { id: /\d{4}/ } do
        member { get :commodities }
      end

      resources :subheadings, only: [:show], constraints: { id: /\d{10}/ } do
        member { get :commodities }
      end

      resources :commodities, only: [:show], constraints: { id: /\d{10}/ } do
        member { get :measures }
      end

      resource :search, only: [] do
        get '/', action: :search, on: :collection, as: ''
      end

      resources :geographical_areas, only: %i[index show]
      resources :measure_types, only: %i[index show]
      resources :certificates, only: [:index]
      resources :certificate_types, only: [:index]
      resources :footnotes, only: [:index]
      resources :footnote_types, only: [:index]
      resources :quota_order_numbers, only: [:index]

      if TradeTariffBackend.uk?
        resources :exchange_rates, only: [:index]
      end

      namespace :reports do
        root to: 'base#index'
      end
    end
  end
end

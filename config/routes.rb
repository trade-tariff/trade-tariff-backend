Rails.application.routes.draw do
  get 'healthcheck' => 'healthcheck#index'

  namespace :api, defaults: { format: 'json' }, path: '/admin' do
    scope module: :admin do
      resources :sections, only: %i[index show], constraints: { id: /\d{1,2}/ } do
        scope module: 'sections', constraints: { section_id: /\d{1,2}/, id: /\d+/ } do
          resource :section_note, only: %i[show create update destroy]
          resources :search_references, only: %i[show index destroy create update]
        end
      end

      resources :updates, only: [:index]
      resources :rollbacks, only: %i[create index]
      resources :footnotes, only: %i[index show update]
      resources :measure_types, only: %i[index show update]
      resources :search_references, only: [:index]

      resources :chapters, only: %i[index show], constraints: { id: /\d{2}/ } do
        scope module: 'chapters', constraints: { chapter_id: /\d{2}/, id: /\d+/ } do
          resource :chapter_note, only: %i[show create update destroy]
          resources :search_references, only: %i[show index destroy create update]
        end
      end

      resources :headings, only: [:show], constraints: { id: /\d{4}/ } do
        scope module: 'headings', constraints: { heading_id: /\d{4}/, id: /\d+/ } do
          resources :search_references, only: %i[show index destroy create update]
        end
      end

      resources :commodities, only: [:show] do
        scope module: 'commodities' do
          resources :search_references, only: %i[show index destroy create update]
        end
      end
    end

    # avoid admin named routes clashing with public api named routes
    namespace :admin, path: '' do
      if TradeTariffBackend.uk?
        resources :news_items, only: %i[index show create update destroy]
      end
    end
  end

  namespace :api, defaults: { format: 'json' }, path: '/' do
    # How (or even if) API versioning will be implemented is still an open question. We can defer
    # the choice until we need to expose the API to clients which we don't control.

    scope module: :v2, constraints: ApiConstraints.new(version: 2) do
      resources :sections, only: %i[index show], constraints: { id: /\d{1,2}/ } do
        collection do
          get :tree
        end
      end

      resources :chapters, only: %i[index show], constraints: { id: /\d{2}/ } do
        member do
          get :changes
        end
      end

      resources :headings, only: [:show], constraints: { id: /\d{4}/ } do
        member do
          get :changes
        end

        resources :validity_periods, only: [:index]
      end

      resources :subheadings, only: [:show], constraints: { id: /\d{10}-\d{2}/ }

      resources :commodities, only: [:show], constraints: { id: /\d{10}/ } do
        member do
          get :changes
        end

        resources :validity_periods, only: [:index]
      end

      resources :geographical_areas, only: %i[index show] do
        collection { get :countries }
      end

      resources :monetary_exchange_rates, only: [:index]

      resources :updates, only: [] do
        collection { get :latest }
      end

      resources :search_references, only: [:index]

      resources :quotas, only: [] do
        collection { get :search }
      end

      resources :certificates, only: [:index] do
        collection { get :search }
      end

      resources :certificate_types, only: [:index]

      resources :measure_types, only: %i[index]

      resources :additional_codes, only: [] do
        collection { get :search }
      end

      resources :additional_code_types, only: [:index]

      resources :footnotes, only: [] do
        collection { get :search }
      end

      resources :footnote_types, only: [:index]

      resources :chemicals, only: %i[index show] do
        collection { get :search }
      end

      resources :rules_of_origin_schemes,
                controller: 'rules_of_origin',
                only: %i[index]
      get '/rules_of_origin_schemes/:heading_code/:country_code',
          to: 'rules_of_origin#index',
          as: :rules_of_origin

      if TradeTariffBackend.uk?
        get '/news_items/:id', constraints: { id: /\d+/ }, to: 'news_items#show', as: :news_item
        get '/news_items', to: 'news_items#index', as: :news_items
      end

      get '/changes(/:as_of)', to: 'changes#index', as: :changes, constraints: { as_of: /\d{4}-\d{1,2}-\d{1,2}/ }

      post 'search' => 'search#search'
      get 'search' => 'search#search'
      get 'search_suggestions' => 'search#suggestions'
      get '/headings/:id/tree' => 'headings#tree'

      get 'goods_nomenclatures/section/:position', to: 'goods_nomenclatures#show_by_section', constraints: { position: /\d{1,2}/ }
      get 'goods_nomenclatures/chapter/:chapter_id', to: 'goods_nomenclatures#show_by_chapter', constraints: { chapter_id: /\d{2}/ }
      get 'goods_nomenclatures/heading/:heading_id', to: 'goods_nomenclatures#show_by_heading', constraints: { heading_id: /\d{4}/ }
    end

    scope module: :v1, constraints: ApiConstraints.new(version: 1) do
      resources :sections, only: %i[index show], constraints: { id: /\d{1,2}/ } do
        collection do
          get :tree
        end
        scope module: 'sections', constraints: { section_id: /\d{1,2}/, id: /\d+/ } do
          resource :section_note, only: %i[show]
        end
      end

      resources :chapters, only: %i[index show], constraints: { id: /\d{2}/ } do
        member do
          get :changes
        end

        scope module: 'chapters', constraints: { chapter_id: /\d{2}/, id: /\d+/ } do
          resource :chapter_note, only: %i[show]
        end
      end

      resources :headings, only: [:show], constraints: { id: /\d{4}/ } do
        member do
          get :changes
        end
      end

      resources :commodities, only: [:show], constraints: { id: /\d{10}/, as_of: /.*/ } do
        member do
          get :changes
        end
      end

      get '/headings/:id/tree' => 'headings#tree'
    end
  end

  root to: 'application#nothing'

  get '*path', to: 'application#render_not_found'
end

require 'routing_filter/service_path_prefix'

Rails.application.routes.draw do
  get 'healthcheck' => 'healthcheck#index'

  scope :api, module: :api do
    filter :service_path_prefix

    scope :beta, module: :beta do
      resources :search, only: %i[index]
    end
  end

  namespace :api, defaults: { format: 'json' }, path: '/admin' do
    scope module: :admin do
      resources :sections, only: %i[index show] do
        scope module: 'sections', constraints: { id: /\d+/ } do
          resource :section_note, only: %i[show create update destroy]
        end
      end

      resources :updates, only: %i[index show]
      resources :rollbacks, only: %i[create index]
      resources :footnotes, only: %i[index show update]
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

      resources :commodities, only: %i[show index] do
        scope module: 'commodities' do
          resources :search_references, only: %i[show index destroy create update]
        end
      end
    end

    # avoid admin named routes clashing with public api named routes
    namespace :admin, path: '' do
      if TradeTariffBackend.uk?
        namespace :news do
          resources :items, only: %i[index show create update destroy]
          resources :collections, only: %i[index]
        end

        resources :news_items, only: %i[index show create update destroy],
                               controller: 'news/items'
      end
    end
  end

  namespace :api, defaults: { format: 'json' }, path: '/' do
    # TODO: The api versioning is hierarchical as far as the defined order of the routes below.
    #
    # If your default api scope (as defined in env['DEFAULT_API_VERSION']) comes before the scopes that are defined below it, then the default scope will always match.
    #
    # For example (broken/incorrect scoping arrangement):
    #   v2 scope (default)
    #   v1 scope (unreachable)
    #   beta scope (unreachable)
    #
    # For example (correct scoping arrangement): (correct)
    #   beta scope (reachable)
    #   v1 scope (reachable)
    #   v2 scope (default)
    #
    # We should adjust this carefully since it's old behaviour

    scope module: :v2, constraints: ApiConstraints.new(version: 2) do
      resources :sections, only: %i[index show] do
        collection do
          get :tree
        end

        member do
          get :chapters
        end
      end

      resources :chapters, only: %i[index show], constraints: { id: /\d{1,2}/ } do
        member do
          get :changes
          get :headings
        end
      end

      resources :headings, only: [:show], constraints: { id: /\d{4}/ } do
        member do
          get :changes
          get :commodities
        end

        resources :validity_periods, only: [:index]
      end

      resources :subheadings, only: [:show] do
        resources :validity_periods, only: [:index]
      end

      resources :commodities, only: [:show], constraints: { id: /\d{10}/ } do
        member do
          get :changes
        end

        resources :validity_periods, only: [:index]
      end

      resources :geographical_areas, only: %i[index show] do
        collection { get :countries }
      end

      resources :preference_codes, only: %i[index show]

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

      resources :measure_actions, only: %i[index]
      resources :measure_condition_codes, only: %i[index]
      resources :quota_order_numbers, only: %i[index]
      resources :measure_types, only: %i[index show]

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

      get 'goods_nomenclatures/section/:position', to: 'goods_nomenclatures#show_by_section', constraints: { position: /\d+/ }
      get 'goods_nomenclatures/chapter/:chapter_id', to: 'goods_nomenclatures#show_by_chapter', constraints: { chapter_id: /\d{2}/ }
      get 'goods_nomenclatures/heading/:heading_id', to: 'goods_nomenclatures#show_by_heading', constraints: { heading_id: /\d{4}/ }
    end

    scope module: :v1, constraints: ApiConstraints.new(version: 1) do
      resources :sections, only: %i[index show] do
        collection do
          get :tree
        end
        scope module: 'sections', constraints: { id: /\d+/ } do
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

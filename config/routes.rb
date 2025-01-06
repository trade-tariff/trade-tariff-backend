Rails.application.routes.draw do
  get 'healthcheck' => 'healthcheck#index'
  get 'healthcheckz' => 'healthcheck#checkz'

  if TradeTariffBackend.enable_admin?
    namespace :api, defaults: { format: 'json' }, path: '/admin' do
      scope module: :admin do
        resources :sections, only: %i[index show] do
          scope module: 'sections', constraints: { id: /\d+/ } do
            resource :section_note, only: %i[show create update destroy]
          end
        end

        resources :updates, only: %i[index show]
        resources :rollbacks, only: %i[create index]
        resources :clear_caches, only: %i[create]
        resources :downloads, only: %i[create]
        resources :applies, only: %i[create]
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

        resources :commodities, only: %i[show] do
          scope module: 'commodities' do
            resources :search_references, only: %i[show index destroy create update]
          end
        end

        resources :quota_order_numbers, module: 'quota_order_numbers', only: %i[] do
          resources :quota_definitions, only: %i[index show]
        end
      end

      # avoid admin named routes clashing with public api named routes
      namespace :admin, path: '' do
        if Rails.env.development? || TradeTariffBackend.uk?
          namespace :news do
            resources :items, only: %i[index show create update destroy]
            resources :collections, only: %i[index show create update]
          end

          resources :news_items, only: %i[index show create update destroy],
                                 controller: 'news/items'
        end

        namespace :green_lanes do
          resources :category_assessments, only: %i[index show create update destroy] do
            member do
              post 'exemptions', to: 'category_assessments#add_exemption'
              delete 'exemptions', to: 'category_assessments#remove_exemption'
            end
          end
          resources :themes, only: %i[index]
          resources :exempting_certificate_overrides, only: %i[index show create destroy]
          resources :exempting_additional_code_overrides, only: %i[index show create destroy]
          resources :exemptions, only: %i[index show create update destroy]
          resources :measures, only: %i[index show create update destroy]
          resources :update_notifications, only: %i[index show update]
        end
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
    #
    # For example (correct scoping arrangement): (correct)
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

      namespace :exchange_rates do
        get 'period_lists(/:year)', to: 'period_lists#show', as: :period_list
        resources :files, only: [:show]
      end

      resources :exchange_rates, only: [:show]

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

      resources :chemical_substances, only: %i[index]
      resources :simplified_procedural_code_measures, only: %i[index]

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
      resources :measures, only: %i[show], constraints: { id: /-?\d+/ }

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

      scope module: :rules_of_origin do
        resources :rules_of_origin_schemes,
                  controller: 'schemes',
                  only: %i[index]
        get '/rules_of_origin_schemes/:heading_code/:country_code',
            to: 'schemes#index',
            as: :rules_of_origin
        get '/rules_of_origin_schemes/:commodity_code',
            to: 'product_specific_rules#index',
            as: :product_specific_rules
      end

      if Rails.env.development? || TradeTariffBackend.uk?
        namespace :news do
          resources :items, only: %i[index show]
          resources :years, only: %i[index]
          resources :collections, only: %i[index] do
            resources :items, only: %i[index], shallow: true
          end
        end

        get '/news_items/:id', to: 'news/items#show', as: nil
        get '/news_items', to: 'news/items#index', as: nil
      end

      get '/changes(/:as_of)', to: 'changes#index', as: :changes, constraints: { as_of: /\d{4}-\d{1,2}-\d{1,2}/ }

      post 'search' => 'search#search'
      get 'search' => 'search#search'
      get 'search_suggestions' => 'search#suggestions'

      if TradeTariffBackend.bulk_search_api_enabled?
        resources :bulk_searches, only: %i[create show]
      end

      get '/headings/:id/tree' => 'headings#tree'

      get 'goods_nomenclatures/section/:position', to: 'goods_nomenclatures#show_by_section', constraints: { position: /\d+/ }
      get 'goods_nomenclatures/chapter/:chapter_id', to: 'goods_nomenclatures#show_by_chapter', constraints: { chapter_id: /\d{2}/ }
      get 'goods_nomenclatures/heading/:heading_id', to: 'goods_nomenclatures#show_by_heading', constraints: { heading_id: /\d{4}/ }
      get 'goods_nomenclatures/:id', to: 'goods_nomenclatures#show', constraints: { id: /\d{4,10}/ }

      namespace :green_lanes do
        resources :goods_nomenclatures, only: %i[show], constraints: { id: /\d{4,10}/ }

        resources :category_assessments, only: %i[index]

        resources :themes, only: %i[index]

        resources :faq_feedback, only: %i[create show], controller: '/api/admin/green_lanes/faq_feedback'
      end
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

  match '/400', to: 'errors#bad_request', via: :all
  match '/404', to: 'errors#not_found', via: :all
  match '/405', to: 'errors#method_not_allowed', via: :all
  match '/406', to: 'errors#not_acceptable', via: :all
  match '/422', to: 'errors#unprocessable_entity', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all
  match '/501', to: 'errors#not_implemented', via: :all
  match '/503', to: 'errors#maintenance', via: :all
end

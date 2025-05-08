class V2Api < ::Rails::Engine
end

V2Api.routes.draw do
  get 'healthcheck' => 'healthcheck#index'

  namespace :api, defaults: { format: 'json' }, path: '/' do
    scope module: :v2 do
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

      resources :subscriptions, only: %i[index destroy] do
        member { patch :unsubscribe }
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

      get '/headings/:id/tree' => 'headings#tree'

      get 'goods_nomenclatures/section/:position', to: 'goods_nomenclatures#show_by_section', constraints: { position: /\d+/ }
      get 'goods_nomenclatures/chapter/:chapter_id', to: 'goods_nomenclatures#show_by_chapter', constraints: { chapter_id: /\d{2}/ }
      get 'goods_nomenclatures/heading/:heading_id', to: 'goods_nomenclatures#show_by_heading', constraints: { heading_id: /\d{4}/ }
      get 'goods_nomenclatures/:id', to: 'goods_nomenclatures#show', constraints: { id: /\d{4,10}/ }

      namespace :green_lanes do
        resources :goods_nomenclatures, only: %i[show], constraints: { id: /\d{4,10}/ }

        resources :category_assessments, only: %i[index]

        resources :themes, only: %i[index]

        resources :faq_feedback, only: %i[create index show]
      end

      match '/400', to: 'errors#bad_request', via: :all
      match '/404', to: 'errors#not_found', via: :all
      match '/405', to: 'errors#method_not_allowed', via: :all
      match '/406', to: 'errors#not_acceptable', via: :all
      match '/422', to: 'errors#unprocessable_entity', via: :all
      match '/500', to: 'errors#internal_server_error', via: :all
      match '/501', to: 'errors#not_implemented', via: :all
      match '/503', to: 'errors#maintenance', via: :all
    end
  end
end

class V2Api < ::Rails::Engine
end

module V2SectionRoutes
  def draw_v2_section_routes
    resources :sections, only: %i[index show] do
      collection { get :tree }
      member { get :chapters }
    end

    resources :chapters, only: %i[index show], constraints: { id: /\d{1,2}/ } do
      member do
        get :changes
        get :headings
      end
    end
  end
end

module V2GoodsRoutes
  def draw_v2_goods_routes
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
      member { get :changes }
      resources :validity_periods, only: [:index]
    end
  end
end

module V2LookupRoutes
  def draw_v2_lookup_routes
    resources :geographical_areas, only: %i[index show] do
      collection { get :countries }
    end
    resources :chemical_substances, only: %i[index]
    resources :simplified_procedural_code_measures, only: %i[index]
    resources :description_intercepts, only: %i[index]
    resources :preference_codes, only: %i[index show]
    resources :monetary_exchange_rates, only: [:index]
  end
end

module V2MeasureRoutes
  def draw_v2_measure_routes
    resources(:updates, only: []) { collection { get :latest } }
    resources :search_references, only: [:index]
    resources(:quotas, only: []) { collection { get :search } }
    resources(:certificates, only: [:index]) { collection { get :search } }
    resources :certificate_types, only: [:index]
    resources :measure_actions, only: %i[index]
    resources :measure_condition_codes, only: %i[index]
    resources :quota_order_numbers, only: %i[index]
    resources :measure_types, only: %i[index show]
    resources :measures, only: %i[show], constraints: { id: /-?\d+/ }
    resources(:additional_codes, only: []) { collection { get :search } }
    resources :additional_code_types, only: [:index]
    resources(:footnotes, only: []) { collection { get :search } }
    resources :footnote_types, only: [:index]
    resources(:chemicals, only: %i[index show]) { collection { get :search } }
  end
end

module V2ExchangeRateRoutes
  def draw_v2_exchange_rate_routes
    return unless TradeTariffBackend.uk?

    namespace :exchange_rates do
      get 'period_lists(/:year)', to: 'period_lists#show', as: :period_list
      resources :files, only: [:show]
    end

    resources :exchange_rates, only: [:show]
  end
end

module V2RulesOfOriginRoutes
  def draw_v2_rules_of_origin_routes
    scope module: :rules_of_origin do
      resources :rules_of_origin_schemes, controller: 'schemes', only: %i[index]
      get '/rules_of_origin_schemes/:heading_code/:country_code',
          to: 'schemes#index',
          as: :rules_of_origin
      get '/rules_of_origin_schemes/:commodity_code',
          to: 'product_specific_rules#index',
          as: :product_specific_rules
    end
  end
end

module V2NewsRoutes
  def draw_v2_news_routes
    return unless Rails.env.development? || TradeTariffBackend.uk?

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
end

module V2SearchRoutes
  def draw_v2_search_routes
    get '/changes(/:as_of)', to: 'changes#index', as: :changes, constraints: { as_of: /\d{4}-\d{1,2}-\d{1,2}/ }
    post 'search' => 'search#search'
    get 'search' => 'search#search'
    get 'search_suggestions' => 'search#suggestions'
    match 'classification_search' => 'classification_search#search', via: %i[get post]

    namespace :knowledge_graph do
      resources :queries, only: %i[create]
    end
  end
end

module V2GoodsNomenclatureRoutes
  def draw_v2_goods_nomenclature_routes
    get '/headings/:id/tree' => 'headings#tree'
    get 'goods_nomenclatures/section/:position', to: 'goods_nomenclatures#show_by_section', constraints: { position: /\d+/ }
    get 'goods_nomenclatures/chapter/:chapter_id', to: 'goods_nomenclatures#show_by_chapter', constraints: { chapter_id: /\d{2}/ }
    get 'goods_nomenclatures/heading/:heading_id', to: 'goods_nomenclatures#show_by_heading', constraints: { heading_id: /\d{4}/ }
    get 'goods_nomenclatures/:id', to: 'goods_nomenclatures#show', constraints: { id: /\d{4,10}/ }
  end
end

module V2GreenLanesRoutes
  def draw_v2_green_lanes_routes
    namespace :green_lanes do
      resources :goods_nomenclatures, only: %i[show], constraints: { id: /\d{4,10}/ }
      resources :themes, only: %i[index]
      resources :faq_feedback, only: %i[create index show]
    end
  end
end

module V2ErrorRoutes
  def draw_v2_error_routes
    match '/400', to: 'errors#bad_request', via: :all
    match '/404', to: 'errors#not_found', via: :all
    match '/405', to: 'errors#method_not_allowed', via: :all
    match '/406', to: 'errors#not_acceptable', via: :all
    match '/422', to: 'errors#unprocessable_content', via: :all
    match '/500', to: 'errors#internal_server_error', via: :all
    match '/501', to: 'errors#not_implemented', via: :all
    match '/503', to: 'errors#maintenance', via: :all
  end
end

module V2RouteRoot
  def draw_v2_routes
    get 'healthcheck' => 'healthcheck#index'

    namespace :api, defaults: { format: 'json' }, path: '/' do
      scope module: :v2 do
        resources :notifications, only: %i[create]
        draw_v2_section_routes
        draw_v2_exchange_rate_routes
        draw_v2_goods_routes
        draw_v2_lookup_routes
        draw_v2_measure_routes
        draw_v2_rules_of_origin_routes
        draw_v2_news_routes
        get 'live_issues', to: 'live_issues#index'
        namespace(:enquiry_form) { resources :submissions, only: %i[create] }
        draw_v2_search_routes
        draw_v2_goods_nomenclature_routes
        draw_v2_green_lanes_routes
        draw_v2_error_routes
      end
    end
  end
end

V2Api.routes.draw do
  extend V2RouteRoot
  extend V2SectionRoutes
  extend V2GoodsRoutes
  extend V2LookupRoutes
  extend V2MeasureRoutes
  extend V2ExchangeRateRoutes
  extend V2RulesOfOriginRoutes
  extend V2NewsRoutes
  extend V2SearchRoutes
  extend V2GoodsNomenclatureRoutes
  extend V2GreenLanesRoutes
  extend V2ErrorRoutes

  draw_v2_routes
end

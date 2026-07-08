class AdminApi < ::Rails::Engine
end

module AdminApiRouteRoot
  def draw_admin_api_routes
    namespace :api, defaults: { format: 'json' }, path: '' do
      scope module: :admin do
        draw_admin_catalogue_routes
        draw_admin_search_and_report_routes
        draw_admin_goods_content_routes
        draw_customs_tariff_update_routes
        resources :quota_order_numbers, module: 'quota_order_numbers', only: [] do
          resources :quota_definitions, only: %i[index show]
        end
      end

      draw_admin_named_routes
    end
  end
end

module AdminApiCatalogueRoutes
  def draw_admin_catalogue_routes
    resources :sections, only: %i[index show] do
      scope module: 'sections', constraints: { id: /\d+/ } do
        resource :section_note, only: %i[show create update destroy]
      end
    end

    resources :chapters, only: %i[index show], constraints: { id: /\d{2}/ } do
      scope module: 'chapters', constraints: { chapter_id: /\d{2}/, id: /\d+/ } do
        resource :chapter_note, only: %i[show create update destroy]
        resources :search_references, only: %i[show index destroy create update]
      end
    end

    draw_admin_heading_and_commodity_routes
  end

  def draw_admin_heading_and_commodity_routes
    resources :headings, only: [:show], constraints: { id: /\d{4}/ } do
      scope module: 'headings', constraints: { heading_id: /\d{4}/, id: /\d+/ } do
        resources :search_references, only: %i[show index destroy create update]
      end
    end

    resources :commodities, as: :admin_commodity, only: %i[show] do
      scope module: 'commodities' do
        resources :search_references, only: %i[show index destroy create update]
      end
    end
  end
end

module AdminApiSearchAndReportRoutes
  def draw_admin_search_and_report_routes
    resources :updates, only: %i[index show]
    resources :rollbacks, only: %i[create index]
    resources :clear_caches, only: %i[create]
    resources :downloads, only: %i[create]
    resources :applies, only: %i[create]
    resources :footnotes, only: %i[index show update]
    resources :search_references, only: [:index]
    resources :search_diagnostics, only: [:show], param: :request_id, constraints: { request_id: /[^\/.]+/ }
    resources :search_analytics, only: [:index]
    resources :cds_update_notifications, only: [:create]
    resources :reports, only: %i[index show], constraints: { id: /[a-z_]+/ } do
      member do
        post :run
        post :send_email
        post :backfill
      end
    end
  end
end

module AdminApiGoodsContentRoutes
  def draw_admin_goods_content_routes
    resources :goods_nomenclatures, only: [], constraints: { id: /\d+/ } do
      scope module: 'goods_nomenclatures' do
        draw_admin_goods_nomenclature_member_routes
      end
    end

    namespace(:goods_nomenclature_labels) { resource :stats, only: [:show] }
    resources :goods_nomenclature_labels, only: [:index]
    resources :goods_nomenclature_self_texts, only: [:index]
    resources :tariff_knowledge_compressed_notes, only: [:index]
    resources(:versions, only: [:index]) { member { post :restore } }
  end

  def draw_admin_goods_nomenclature_member_routes
    resource :goods_nomenclature_label, only: %i[show update] do
      post :score
      post :regenerate
      post :approve
      post :reject
      get :versions
    end

    resource :goods_nomenclature_self_text, only: %i[show update] do
      post :score
      post :regenerate
      post :approve
      post :reject
      get :versions
    end

    resource :tariff_knowledge_compressed_note, only: %i[show update] do
      post :regenerate
      post :approve
      post :reject
      get :versions
    end
  end
end

module AdminApiCustomsTariffUpdateRoutes
  def draw_customs_tariff_update_routes
    get 'customs_tariff_updates', to: 'customs_tariff_updates#index'
    get 'customs_tariff_updates/:version', to: 'customs_tariff_updates#show', constraints: { version: /\d+\.\d+/ }
    draw_customs_tariff_update_section_note_routes
    draw_customs_tariff_update_chapter_note_routes
    post 'customs_tariff_updates/:customs_tariff_update_version/reimport',
         to: 'customs_tariff_updates/reimport#create',
         constraints: customs_tariff_update_constraints
    get 'customs_tariff_updates/:customs_tariff_update_version/sections_summary',
        to: 'customs_tariff_updates/sections_summary#index',
        constraints: customs_tariff_update_constraints
  end

  def draw_customs_tariff_update_section_note_routes
    get 'customs_tariff_updates/:customs_tariff_update_version/section_notes',
        to: 'customs_tariff_updates/section_notes#index',
        constraints: customs_tariff_update_constraints
    get 'customs_tariff_updates/:customs_tariff_update_version/section_notes/:id',
        to: 'customs_tariff_updates/section_notes#show',
        constraints: customs_tariff_update_constraints
    patch 'customs_tariff_updates/:customs_tariff_update_version/section_notes/:id',
          to: 'customs_tariff_updates/section_notes#update',
          constraints: customs_tariff_update_constraints
    post 'customs_tariff_updates/:customs_tariff_update_version/section_notes',
         to: 'customs_tariff_updates/section_notes#create',
         constraints: customs_tariff_update_constraints
    delete 'customs_tariff_updates/:customs_tariff_update_version/section_notes/:id',
           to: 'customs_tariff_updates/section_notes#destroy',
           constraints: customs_tariff_update_constraints
  end

  def draw_customs_tariff_update_chapter_note_routes
    get 'customs_tariff_updates/:customs_tariff_update_version/chapter_notes',
        to: 'customs_tariff_updates/chapter_notes#index',
        constraints: customs_tariff_update_constraints
    get 'customs_tariff_updates/:customs_tariff_update_version/chapter_notes/:id',
        to: 'customs_tariff_updates/chapter_notes#show',
        constraints: customs_tariff_update_constraints
    patch 'customs_tariff_updates/:customs_tariff_update_version/chapter_notes/:id',
          to: 'customs_tariff_updates/chapter_notes#update',
          constraints: customs_tariff_update_constraints
    delete 'customs_tariff_updates/:customs_tariff_update_version/chapter_notes/:id',
           to: 'customs_tariff_updates/chapter_notes#destroy',
           constraints: customs_tariff_update_constraints
    post 'customs_tariff_updates/:customs_tariff_update_version/chapter_notes',
         to: 'customs_tariff_updates/chapter_notes#create',
         constraints: customs_tariff_update_constraints
  end

  def customs_tariff_update_constraints
    { customs_tariff_update_version: /[^\/]+/ }
  end
end

module AdminApiNamedRoutes
  def draw_admin_named_routes
    namespace :admin, path: '' do
      draw_uk_admin_routes
      draw_green_lanes_admin_routes
    end
  end

  def draw_uk_admin_routes
    return unless Rails.env.development? || TradeTariffBackend.uk?

    namespace :news do
      resources :items, only: %i[index show create update destroy]
      resources :collections, only: %i[index show create update]
    end

    resources :news_items, only: %i[index show create update destroy], controller: 'news/items'
    resources :live_issues, only: %i[index show create update destroy]
    resources :admin_configurations, only: %i[index show update]
    resources :description_intercepts, only: %i[index show create update destroy] do
      collection { post :bulk_import }
      member { get :versions }
    end
    resources :goods_nomenclature_autocomplete, only: [:index]
  end

  def draw_green_lanes_admin_routes
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
      resources :measure_type_mappings, only: %i[index show create destroy]
    end
  end
end

AdminApi.routes.draw do
  extend AdminApiRouteRoot
  extend AdminApiCatalogueRoutes
  extend AdminApiSearchAndReportRoutes
  extend AdminApiGoodsContentRoutes
  extend AdminApiCustomsTariffUpdateRoutes
  extend AdminApiNamedRoutes

  draw_admin_api_routes
end

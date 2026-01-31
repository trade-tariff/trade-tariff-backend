class AdminApi < ::Rails::Engine
end

AdminApi.routes.draw do
  namespace :api, defaults: { format: 'json' }, path: '' do
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
      resources :cds_update_notifications, only: [:create]

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

      resources :commodities, as: :admin_commodity, only: %i[show] do
        scope module: 'commodities' do
          resources :search_references, only: %i[show index destroy create update]
        end
      end

      resources :goods_nomenclatures, only: %i[], constraints: { id: /\d{10}/ } do
        scope module: 'goods_nomenclatures' do
          resource :goods_nomenclature_label, only: %i[show update]
        end
      end

      namespace :goods_nomenclature_labels do
        resource :stats, only: [:show]
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

        resources :live_issues, only: %i[index show create update destroy]
        resources :admin_configurations, only: %i[index show update]
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
        resources :measure_type_mappings, only: %i[index show create destroy]
      end
    end
  end
end

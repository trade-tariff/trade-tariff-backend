Rails.application.routes.draw do
  root to: 'application#nothing'

  # Application liveness
  get 'healthcheckz' => 'healthcheck#checkz'

  # Legacy routes
  mount V2Api => '/', as: 'v2', constraints: ApiConstraints.new(version: 2)
  mount V1Api => '/', as: 'v1', constraints: ApiConstraints.new(version: 1)

  # V1 routes
  mount V1Api => '/api/v1', as: 'v1_api'
  mount V1Api => '/xi/api/v1', as: 'xi_v1_api' if TradeTariffBackend.xi?
  mount V1Api => '/uk/api/v1', as: 'uk_v1_api' if TradeTariffBackend.uk?

  # V2 routes
  mount V2Api => '/api/v2', as: 'v2_api'
  mount V2Api => '/xi/api/v2', as: 'xi_v2_api' if TradeTariffBackend.xi?
  mount V2Api => '/uk/api/v2', as: 'uk_v2_api' if TradeTariffBackend.uk?

  # Admin routes
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

        resources :commodities, as: :admin_commodity, only: %i[show] do
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

  match '/400', to: 'errors#bad_request', via: :all
  match '/404', to: 'errors#not_found', via: :all
  match '/405', to: 'errors#method_not_allowed', via: :all
  match '/406', to: 'errors#not_acceptable', via: :all
  match '/422', to: 'errors#unprocessable_entity', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all
  match '/501', to: 'errors#not_implemented', via: :all
  match '/503', to: 'errors#maintenance', via: :all
end

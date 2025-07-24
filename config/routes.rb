Rails.application.routes.draw do
  root to: 'application#nothing'

  # Application liveness
  get 'healthcheckz' => 'healthcheck#checkz'

  # Error handling
  draw(:errors)

  # Sidekiq web interface
  draw(:sidekiq)

  # Admin routes
  mount AdminApi => '/uk/admin', as: 'uk_admin_api' if TradeTariffBackend.uk?
  mount AdminApi => '/xi/admin', as: 'xi_admin_api' if TradeTariffBackend.xi?

  # User routes
  mount UserApi => '/uk/user', as: 'uk_user_api' if TradeTariffBackend.uk?

  # V1 routes
  mount V1Api => '/uk/api', as: 'uk_v1_versioned_api', constraints: VersionedAcceptHeader.new(version: 1.0) if TradeTariffBackend.uk?
  mount V1Api => '/xi/api', as: 'xi_v1_versioned_api', constraints: VersionedAcceptHeader.new(version: 1.0) if TradeTariffBackend.xi?

  # V2 routes
  mount V2Api => '/uk/api', as: 'uk_v2_versioned_api', constraints: VersionedAcceptHeader.new(version: 2.0) if TradeTariffBackend.uk?
  mount V2Api => '/xi/api', as: 'xi_v2_versioned_api', constraints: VersionedAcceptHeader.new(version: 2.0) if TradeTariffBackend.xi?

  match '/:service/api/v:version/*path',
        via: :all,
        to: VersionedForwarder.new,
        constraints: { service: /uk|xi/, version: /\d+/ }

  match '/api/*path', via: :all, to: redirect { |params, request| "/uk/api/#{params[:path]}?#{request.query_string}" } if TradeTariffBackend.uk?
  match '/api/*path', via: :all, to: redirect { |params, request| "/xi/api/#{params[:path]}?#{request.query_string}" } if TradeTariffBackend.xi?
end

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

  # Internal routes
  mount InternalApi => '/uk/internal', as: 'uk_internal_api' if TradeTariffBackend.uk?
  mount InternalApi => '/xi/internal', as: 'xi_internal_api' if TradeTariffBackend.xi?

  # User routes
  mount UserApi => '/uk/user', as: 'uk_user_api' if TradeTariffBackend.uk?

  # V1 routes - disabled
  v1_gone = ->(_env) { [404, { 'Content-Type' => 'application/json' }, ['{"errors":[{"detail":"This version of the API is no longer supported. Please upgrade to v2. See https://docs.trade-tariff.service.gov.uk/reference.html"}]}']] }
  match '(/:service)/api/v1(/*path)', via: :all, to: v1_gone, constraints: { service: /uk|xi/ }
  match '/uk/api/*path', via: :all, to: v1_gone, constraints: VersionedAcceptHeader.new(version: 1.0)
  match '/xi/api/*path', via: :all, to: v1_gone, constraints: VersionedAcceptHeader.new(version: 1.0)

  # V2 routes
  mount V2Api => '/uk/api', as: 'uk_v2_versioned_api', constraints: VersionedAcceptHeader.new(version: 2.0) if TradeTariffBackend.uk?
  mount V2Api => '/xi/api', as: 'xi_v2_versioned_api', constraints: VersionedAcceptHeader.new(version: 2.0) if TradeTariffBackend.xi?

  match '(/:service)/api/v:version(/*path)',
        via: :all,
        to: VersionedForwarder.new,
        constraints: { version: /\d+/, service: /uk|xi/ }
end

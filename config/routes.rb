Rails.application.routes.draw do
  root to: 'application#nothing'

  # Application liveness
  get 'healthcheckz' => 'healthcheck#checkz'

  # Error handling
  draw(:errors)

  # Sidekiq web interface
  draw(:sidekiq)

  # Admin routes
  mount AdminApi => '/xi', as: 'xi_admin_api' if TradeTariffBackend.xi?
  mount AdminApi => '/uk', as: 'uk_admin_api' if TradeTariffBackend.uk?
  mount AdminApi => '/', as: 'admin' # TODO: Remove me once admin is migrated off

  # V1 routes
  mount V1Api => '/api/v1', as: 'v1_api' # TODO: Redirect these to the UK routes below in the ALB and remove
  mount V1Api => '/xi/api/v1', as: 'xi_v1_api' if TradeTariffBackend.xi?
  mount V1Api => '/uk/api/v1', as: 'uk_v1_api' if TradeTariffBackend.uk?

  # V2 routes
  mount V2Api => '/api/xi', as: 'xi_v2_versioned_api', constraints: VersionedAcceptHeader.new(version: 2.0) if TradeTariffBackend.xi?
  mount V2Api => '/api/uk', as: 'uk_v2_versioned_api', constraints: VersionedAcceptHeader.new(version: 2.0) if TradeTariffBackend.uk?

  # TODO: Redirect these to the V2 routes above in the ALB and remove
  mount V2Api => '/api/v2', as: 'v2_api'
  mount V2Api => '/xi/api/v2', as: 'xi_v2_api' if TradeTariffBackend.xi?
  mount V2Api => '/uk/api/v2', as: 'uk_v2_api' if TradeTariffBackend.uk?

  mount UserApi => '/uk', as: 'uk_user_api' if TradeTariffBackend.uk?
  mount UserApi => '/', as: 'user' # TODO: Remove me
end

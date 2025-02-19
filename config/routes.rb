Rails.application.routes.draw do
  root to: 'application#nothing'

  # Application liveness
  get 'healthcheckz' => 'healthcheck#checkz'

  # Admin routes
  draw(:admin) if TradeTariffBackend.enable_admin?

  # Error handling
  draw(:errors)

  # V1 routes
  mount V1Api => '/api/v1', as: 'v1_api'
  mount V1Api => '/xi/api/v1', as: 'xi_v1_api' if TradeTariffBackend.xi?
  mount V1Api => '/uk/api/v1', as: 'uk_v1_api' if TradeTariffBackend.uk?

  # V2 routes
  mount V2Api => '/api/v2', as: 'v2_api'
  mount V2Api => '/xi/api/v2', as: 'xi_v2_api' if TradeTariffBackend.xi?
  mount V2Api => '/uk/api/v2', as: 'uk_v2_api' if TradeTariffBackend.uk?

  # Legacy routes
  mount V2Api => '/', as: 'v2', constraints: ApiConstraints.new(version: 2)
  mount V1Api => '/', as: 'v1', constraints: ApiConstraints.new(version: 1)
end

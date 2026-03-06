Rails.application.routes.draw do
  root to: 'application#nothing'

  # Application liveness
  get 'healthcheckz' => 'healthcheck#checkz'

  # Error handling
  draw(:errors)

  # Sidekiq web interface
  draw(:sidekiq)

  # Admin routes (xi first so uk is the preferred mount for route helpers)
  mount AdminApi => '/xi/admin', as: 'xi_admin_api'
  mount AdminApi => '/uk/admin', as: 'uk_admin_api'

  # Internal routes
  mount InternalApi => '/xi/internal', as: 'xi_internal_api'
  mount InternalApi => '/uk/internal', as: 'uk_internal_api'

  # User routes
  mount UserApi => '/uk/user', as: 'uk_user_api'

  # V1 routes (xi first so uk is the preferred mount for route helpers)
  mount V1Api => '/xi/api', as: 'xi_v1_versioned_api', constraints: VersionedAcceptHeader.new(version: 1.0)
  mount V1Api => '/uk/api', as: 'uk_v1_versioned_api', constraints: VersionedAcceptHeader.new(version: 1.0)

  # V2 routes (xi first so uk is the preferred mount for route helpers)
  mount V2Api => '/xi/api', as: 'xi_v2_versioned_api', constraints: VersionedAcceptHeader.new(version: 2.0)
  mount V2Api => '/uk/api', as: 'uk_v2_versioned_api', constraints: VersionedAcceptHeader.new(version: 2.0)

  match '(/:service)/api/v:version(/*path)',
        via: :all,
        to: VersionedForwarder.new,
        constraints: { version: /\d+/, service: /uk|xi/ }
end

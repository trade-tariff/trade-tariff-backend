require 'sidekiq/web'

Sidekiq::Web.use ActionDispatch::Cookies
Sidekiq::Web.use Rails.application.config.session_store, Rails.application.config.session_options

mount Sidekiq::Web => '/sidekiq', as: 'sidekiq'
mount Sidekiq::Web => '/uk/sidekiq', as: 'uk_sidekiq' if TradeTariffBackend.uk?
mount Sidekiq::Web => '/xi/sidekiq', as: 'xi_sidekiq' if TradeTariffBackend.xi?

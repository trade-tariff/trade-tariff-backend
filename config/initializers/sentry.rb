Sentry.init do |config|
  config.breadcrumbs_logger = %i[active_support_logger http_logger]

  config.excluded_exceptions += %w[
    Sequel::Plugins::RailsExtensions::ModelNotFound
    Sequel::NoMatchingRow
    Sequel::RecordNotFound
    MaintenanceMode::MaintenanceModeActive
  ]

  config.traces_sample_rate = 1.0

  config.profiles_sample_rate = 1.0
end

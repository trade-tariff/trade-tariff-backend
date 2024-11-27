Sentry.init do |config|
  config.breadcrumbs_logger = [:active_support_logger]

  config.excluded_exceptions += %w[
    Sequel::Plugins::RailsExtensions::ModelNotFound
    Sequel::NoMatchingRow
    Sequel::RecordNotFound
    MaintenanceMode::MaintenanceModeActive
  ]
end

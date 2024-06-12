Sentry.init do |config|
  config.breadcrumbs_logger = [:active_support_logger]

  config.excluded_exceptions += %w[
    Sequel::Plugins::RailsExtensions::ModelNotFound
    Sequel::NoMatchingRow
    Sequel::RecordNotFound
    ActionController::ParameterMissing
    NotImplementedError
    BulkSearch::ResultCollection::RecordNotFound
    MaintenanceMode::MaintenanceModeActive
  ]
end

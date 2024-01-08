ActionDispatch::ExceptionWrapper.rescue_responses.merge!(
  'ArgumentError' => :bad_request,
  'NotImplementedError' => :unprocessable_entity,
  'ActionController::ParameterMissing' => :unprocessable_entity,
  'Sequel::RecordNotFound' => :not_found,
  'Sequel::NoMatchingRow' => :not_found,
  'BulkSearch::ResultCollection::RecordNotFound' => :not_found,
  'ActionController::RoutingError' => :not_found,
  'AbstractController::ActionNotFound' => :not_found,
  'MaintenanceMode::MaintenanceModeActive' => :service_unavailable,
)

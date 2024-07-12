ActionDispatch::ExceptionWrapper.rescue_responses.merge!(
  'ArgumentError' => :bad_request,
  'NotImplementedError' => :bad_request,
  'Sequel::RecordNotFound' => :not_found,
  'ActionController::RoutingError' => :not_found,
  'AbstractController::ActionNotFound' => :not_found,
  'MaintenanceMode::MaintenanceModeActive' => :service_unavailable,
)

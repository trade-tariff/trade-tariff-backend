Sentry.init do |config|
  config.rails.report_rescued_exceptions = false

  config.breadcrumbs_logger = [:active_support_logger]
end

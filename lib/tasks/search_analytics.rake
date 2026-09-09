# frozen_string_literal: true

namespace :search_analytics do
  desc 'Render the actual Terraform dashboard queries without AWS access'
  task :render_dashboard_queries do # rubocop:disable Rails/RakeEnvironment
    require Rails.root.join('app/services/search_analytics/dashboard_query_catalog')

    catalog = SearchAnalytics::DashboardQueryCatalog.call(log_group_name: ENV.fetch('CLOUDWATCH_QUERY_VALIDATION_LOG_GROUP'))
    File.write(ENV.fetch('CLOUDWATCH_DASHBOARD_QUERIES_FILE'), JSON.pretty_generate(catalog))
  end # rubocop:enable Rails/RakeEnvironment

  desc 'Validate generated CloudWatch Logs Insights queries in AWS'
  # This CI task deliberately avoids booting the database-backed Rails environment.
  task :validate_cloudwatch_queries do # rubocop:disable Rails/RakeEnvironment
    %w[period cloudwatch_snapshot_query snapshot_refresh cloudwatch_query_validator].each do |service|
      require Rails.root.join("app/services/search_analytics/#{service}")
    end

    SearchAnalytics::CloudwatchQueryValidator.call(
      log_group_name: ENV.fetch('CLOUDWATCH_QUERY_VALIDATION_LOG_GROUP'),
      dashboard_queries: ENV['CLOUDWATCH_DASHBOARD_QUERIES_FILE'] ? JSON.parse(File.read(ENV.fetch('CLOUDWATCH_DASHBOARD_QUERIES_FILE'))) : {},
    )
  end # rubocop:enable Rails/RakeEnvironment
end

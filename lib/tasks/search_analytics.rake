# frozen_string_literal: true

namespace :search_analytics do
  desc 'Validate generated CloudWatch Logs Insights queries in AWS'
  # This CI task deliberately avoids booting the database-backed Rails environment.
  task :validate_cloudwatch_queries do # rubocop:disable Rails/RakeEnvironment
    %w[period cloudwatch_snapshot_query snapshot_refresh cloudwatch_query_validator].each do |service|
      require Rails.root.join("app/services/search_analytics/#{service}")
    end

    SearchAnalytics::CloudwatchQueryValidator.call(
      log_group_name: ENV.fetch('CLOUDWATCH_QUERY_VALIDATION_LOG_GROUP'),
    )
  end # rubocop:enable Rails/RakeEnvironment
end

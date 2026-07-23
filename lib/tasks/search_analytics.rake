# frozen_string_literal: true

namespace :search_analytics do
  desc 'Validate generated CloudWatch Logs Insights queries in AWS'
  task validate_cloudwatch_queries: :environment do
    SearchAnalytics::CloudwatchQueryValidator.call(
      log_group_name: ENV.fetch('CLOUDWATCH_QUERY_VALIDATION_LOG_GROUP'),
    )
  end
end

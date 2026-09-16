# frozen_string_literal: true

namespace :search_analytics do # rubocop:disable Metrics/BlockLength
  desc 'Queue daily query collection asynchronously (DAYS=30, FORCE=true optional)'
  task backfill: :environment do
    days = Integer(ENV.fetch('DAYS', '30'), 10)
    ids = SearchAnalyticsQueryWorker.enqueue_backfill(
      days:, region: ENV.fetch('AWS_REGION', ENV.fetch('AWS_DEFAULT_REGION', 'eu-west-2')),
      force: %w[true 1].include?(ENV['FORCE'].to_s.downcase)
    )
    puts "Queued #{ids.size} day jobs for #{days} completed UTC days ending yesterday"
  end

  desc 'Queue missing queries for a completed UTC day (REPORTING_DATE, QUERIES, FORCE=true optional)'
  task collect_day: :environment do
    date = ENV['REPORTING_DATE'] ? Date.iso8601(ENV.fetch('REPORTING_DATE')) : Time.current.utc.to_date - 1
    ids = SearchAnalyticsQueryWorker.enqueue_day(
      reporting_date: date,
      region: ENV.fetch('AWS_REGION', ENV.fetch('AWS_DEFAULT_REGION', 'eu-west-2')),
      queries: ENV['QUERIES']&.split(',')&.map(&:strip), force: %w[true 1].include?(ENV['FORCE'].to_s.downcase)
    )
    puts "Queued #{ids.size} queries for #{date.iso8601}"
  end

  desc 'Render the actual Terraform dashboard queries without AWS access'
  task :render_dashboard_queries do # rubocop:disable Rails/RakeEnvironment
    require Rails.root.join('app/services/search_analytics/dashboard_query_catalog')

    catalog = SearchAnalytics::DashboardQueryCatalog.call(log_group_name: ENV.fetch('CLOUDWATCH_QUERY_VALIDATION_LOG_GROUP'))
    File.write(ENV.fetch('CLOUDWATCH_DASHBOARD_QUERIES_FILE'), JSON.pretty_generate(catalog))
  end # rubocop:enable Rails/RakeEnvironment

  desc 'Validate generated CloudWatch Logs Insights queries in AWS'
  # This CI task deliberately avoids booting the database-backed Rails environment.
  task :validate_cloudwatch_queries do # rubocop:disable Rails/RakeEnvironment
    %w[period cloudwatch_snapshot_query journey_queries latency_histogram daily_query cloudwatch_query_validator].each do |service|
      require Rails.root.join("app/services/search_analytics/#{service}")
    end

    SearchAnalytics::CloudwatchQueryValidator.call(
      log_group_name: ENV.fetch('CLOUDWATCH_QUERY_VALIDATION_LOG_GROUP'),
      dashboard_queries: ENV['CLOUDWATCH_DASHBOARD_QUERIES_FILE'] ? JSON.parse(File.read(ENV.fetch('CLOUDWATCH_DASHBOARD_QUERIES_FILE'))) : {},
    )
  end # rubocop:enable Rails/RakeEnvironment
end

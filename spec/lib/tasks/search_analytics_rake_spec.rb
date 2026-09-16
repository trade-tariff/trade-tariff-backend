RSpec.describe 'search analytics rake tasks' do
  describe 'search_analytics:validate_cloudwatch_queries' do
    subject(:task) { Rake::Task['search_analytics:validate_cloudwatch_queries'] }

    it 'runs without booting the Rails environment' do
      expect(task.prerequisites).not_to include('environment')
    end

    it 'loads the daily SQL dependencies in a database-free rake process' do
      Tempfile.create(['analytics-validator-client', '.rb']) do |file|
        file.write(<<~RUBY)
          require 'aws-sdk-cloudwatchlogs'
          Aws::CloudWatchLogs::Client.singleton_class.prepend(Module.new do
            def new(**options)
              super(**options, stub_responses: true).tap do |client|
                client.stub_responses(:start_query, query_id: 'offline-query')
                client.stub_responses(:get_query_results, status: 'Complete', results: [])
              end
            end
          end)
        RUBY
        file.flush
        output, status = Open3.capture2e(
          { 'CLOUDWATCH_QUERY_VALIDATION_LOG_GROUP' => 'validation-logs',
            'CLOUDWATCH_DASHBOARD_QUERIES_FILE' => nil,
            'DATABASE_URL' => 'postgresql://invalid.invalid/no_database',
            'AWS_REGION' => 'eu-west-2' },
          'bundle', 'exec', 'rake', '--require', file.path, task.name
        )
        expect(status.success?).to be(true), output
        expect(output).to include('Validated daily/search_journeys', 'Validated 9 distinct CloudWatch queries')
      end
    end
  end
end

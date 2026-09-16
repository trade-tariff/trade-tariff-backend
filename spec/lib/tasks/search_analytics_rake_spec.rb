RSpec.describe 'search analytics rake tasks' do
  describe 'search_analytics:collect_day' do
    let(:task) { Rake::Task['search_analytics:collect_day'] }

    before do
      task.reenable
      allow(SearchAnalyticsQueryWorker).to receive(:enqueue_day).and_return(%w[job-one job-two])
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:fetch).and_call_original
    end

    it 'queues yesterday by default without forcing successful queries' do
      allow(ENV).to receive(:[]).with('REPORTING_DATE').and_return(nil)
      allow(ENV).to receive(:[]).with('QUERIES').and_return(nil)
      allow(ENV).to receive(:[]).with('FORCE').and_return(nil)
      expect { task.invoke }.to output(/Queued 2 queries/).to_stdout
      expect(SearchAnalyticsQueryWorker).to have_received(:enqueue_day).with(hash_including(reporting_date: Time.current.utc.to_date - 1, queries: nil, force: false))
    end

    it 'passes explicit date, query selection and force to the queue helper' do
      allow(ENV).to receive(:[]).with('REPORTING_DATE').and_return('2026-09-14')
      allow(ENV).to receive(:fetch).with('REPORTING_DATE').and_return('2026-09-14')
      allow(ENV).to receive(:[]).with('QUERIES').and_return('volume, ai_cost_trend')
      allow(ENV).to receive(:[]).with('FORCE').and_return('1')
      expect { task.invoke }.to output("Queued 2 queries for 2026-09-14\n").to_stdout
      expect(SearchAnalyticsQueryWorker).to have_received(:enqueue_day).with(hash_including(reporting_date: Date.new(2026, 9, 14), queries: %w[volume ai_cost_trend], force: true))
    end
  end

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

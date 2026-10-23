require 'erb'
require 'yaml'
require 'sidekiq/cli'

RSpec.describe 'config/sidekiq.yml' do
  def capsule_configuration
    cli = Sidekiq::CLI.new
    cli.config = Sidekiq::Config.new
    cli.parse(['-C', Rails.root.join('config/sidekiq.yml').to_s])
    cli.config
  end

  describe 'capsules' do
    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('SIDEKIQ_CONCURRENCY', 10).and_return('10')
    end

    it 'reserves capacity for each queue within the total thread budget' do
      config = capsule_configuration

      expect(config.capsules.transform_values(&:concurrency)).to eq(
        'default' => 2,
        'sync' => 1,
        'within_1_minute' => 3,
        'within_1_hour' => 2,
        'within_1_day' => 1,
        'evaluation' => 1,
      )
      expect(config.total_concurrency).to eq(10)
      config.capsules.each do |name, capsule|
        expect(capsule.queues).to eq([name])
      end
    end

    it 'allocates additional configured capacity to the default queue' do
      allow(ENV).to receive(:fetch).with('SIDEKIQ_CONCURRENCY', 10).and_return('14')

      config = capsule_configuration

      expect(config.total_concurrency).to eq(14)
      expect(config.default_capsule.concurrency).to eq(6)
      expect(config.capsules.fetch('sync').concurrency).to eq(1)
    end

    it 'supports the minimum thread budget' do
      allow(ENV).to receive(:fetch).with('SIDEKIQ_CONCURRENCY', 10).and_return('9')

      config = capsule_configuration

      expect(config.total_concurrency).to eq(9)
      expect(config.default_capsule.concurrency).to eq(1)
    end

    it 'rejects a thread budget that leaves no capacity for the default queue' do
      allow(ENV).to receive(:fetch).with('SIDEKIQ_CONCURRENCY', 10).and_return('8')

      expect { capsule_configuration }.to raise_error(ArgumentError, /must be at least 9/)
    end
  end

  def sidekiq_schedule(environment:, service: 'uk', rails_env: 'production')
    original_environment = ENV.fetch('ENVIRONMENT', nil)
    original_service = ENV.fetch('SERVICE', nil)
    original_rails_env = ENV.fetch('RAILS_ENV', nil)
    ENV['ENVIRONMENT'] = environment
    ENV['SERVICE'] = service
    ENV['RAILS_ENV'] = rails_env

    begin
      YAML.safe_load(ERB.new(Rails.root.join('config/sidekiq.yml').read).result, permitted_classes: [Symbol], aliases: true)
        .fetch(:scheduler)
        .fetch(:schedule)
    ensure
      ENV['ENVIRONMENT'] = original_environment
      ENV['SERVICE'] = original_service
      ENV['RAILS_ENV'] = original_rails_env
    end
  end

  it 'schedules the tariff knowledge compressed note refresh pipeline in staging' do
    schedule = sidekiq_schedule(environment: 'staging')

    expect(schedule).to include(
      'RefreshTariffKnowledgeCompressedNotesWorker' => include(
        'cron' => '0 3 * * *',
        'enabled' => true,
      ),
    )
    expect(schedule).not_to include('CreateTariffKnowledgeSourceGraphWorker')
    expect(schedule).not_to include('CreateTariffKnowledgeDeclarableNodesWorker')
  end

  it 'schedules the tariff knowledge compressed note refresh pipeline in production' do
    schedule = sidekiq_schedule(environment: 'production')

    expect(schedule).to include(
      'RefreshTariffKnowledgeCompressedNotesWorker' => include(
        'cron' => '0 3 * * *',
        'enabled' => true,
      ),
    )
  end

  it 'schedules yesterday collection once daily for each backend service' do
    uk_schedule = sidekiq_schedule(environment: 'production', service: 'uk')
    xi_schedule = sidekiq_schedule(environment: 'production', service: 'xi')

    [uk_schedule, xi_schedule].each do |schedule|
      expect(schedule).to include(
        'SearchAnalyticsQueryWorker' => include(
          'cron' => '0 4 * * *',
          'queue' => 'within_1_day',
          'description' => 'Queues missing daily search analytics queries for yesterday',
        ),
      )
      expect(schedule.fetch('SearchAnalyticsQueryWorker')).not_to include('enabled' => false)
      expect(schedule).not_to have_key('SearchAnalyticsSnapshotWorker')
    end
  end

  it 'does not schedule search analytics collection locally, where there are no AWS credentials' do
    schedule = sidekiq_schedule(environment: 'development', rails_env: 'development')

    expect(schedule.fetch('SearchAnalyticsQueryWorker')).to include('enabled' => false)
  end

  it 'schedules the search reference changes report for the first Monday of each month for each backend service' do
    %w[uk xi].each do |service|
      job = sidekiq_schedule(environment: 'production', service:).fetch('SearchReferenceChangesReportWorker')
      cron = Fugit::Cron.parse(job.fetch('cron'))

      expect(job).not_to include('enabled' => false)
      expect(cron.next_time(Time.utc(2026, 10, 14)).to_t).to eq(Time.utc(2026, 11, 2, 10, 30))
      expect(cron.next_time(Time.utc(2027, 4, 1)).to_t).to eq(Time.utc(2027, 4, 5, 9, 30))
    end
  end
end

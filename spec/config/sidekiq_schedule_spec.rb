require 'erb'
require 'yaml'

RSpec.describe 'config/sidekiq.yml' do
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

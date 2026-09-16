require 'erb'
require 'yaml'

RSpec.describe 'config/sidekiq.yml' do
  def sidekiq_schedule(environment:, service: 'uk')
    original_environment = ENV.fetch('ENVIRONMENT', nil)
    original_service = ENV.fetch('SERVICE', nil)
    ENV['ENVIRONMENT'] = environment
    ENV['SERVICE'] = service

    begin
      YAML.safe_load(ERB.new(Rails.root.join('config/sidekiq.yml').read).result, permitted_classes: [Symbol], aliases: true)
        .fetch(:scheduler)
        .fetch(:schedule)
    ensure
      ENV['ENVIRONMENT'] = original_environment
      ENV['SERVICE'] = original_service
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
end

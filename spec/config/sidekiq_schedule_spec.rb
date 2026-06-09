require 'erb'
require 'yaml'

# rubocop:disable RSpec/DescribeClass
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

  it 'schedules tariff knowledge graph population jobs in staging' do
    schedule = sidekiq_schedule(environment: 'staging')

    expect(schedule).to include(
      'CreateTariffKnowledgeSourceGraphWorker' => include(
        'cron' => '0 2 * * *',
        'enabled' => true,
      ),
      'CreateTariffKnowledgeDeclarableNodesWorker' => include(
        'cron' => '30 2 * * *',
        'enabled' => true,
      ),
      'RefreshTariffKnowledgeCompressedNotesWorker' => include(
        'cron' => '0 3 * * *',
        'enabled' => true,
      ),
    )
  end

  it 'keeps tariff knowledge graph schedules disabled outside staging' do
    schedule = sidekiq_schedule(environment: 'production')

    expect(schedule).to include(
      'CreateTariffKnowledgeSourceGraphWorker' => include('enabled' => false),
      'CreateTariffKnowledgeDeclarableNodesWorker' => include('enabled' => false),
      'RefreshTariffKnowledgeCompressedNotesWorker' => include('enabled' => false),
    )
  end
end
# rubocop:enable RSpec/DescribeClass

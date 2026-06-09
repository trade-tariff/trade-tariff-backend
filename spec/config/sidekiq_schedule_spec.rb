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

  it 'keeps tariff knowledge compressed note refresh disabled outside staging' do
    schedule = sidekiq_schedule(environment: 'production')

    expect(schedule).to include(
      'RefreshTariffKnowledgeCompressedNotesWorker' => include('enabled' => false),
    )
  end
end
# rubocop:enable RSpec/DescribeClass

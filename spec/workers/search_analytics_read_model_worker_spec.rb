RSpec.describe SearchAnalyticsReadModelWorker do
  subject(:worker) { described_class.new }

  let(:region) { ENV.fetch('AWS_REGION', ENV.fetch('AWS_DEFAULT_REGION', 'eu-west-2')) }

  it 'does not build anything before an operator bootstraps a generation' do
    expect(SearchAnalytics::ReadModelRefresh).not_to receive(:call)
    worker.perform
  end

  it 'checks bootstrapped data through the revision-aware rebuild service' do
    create(:search_analytics_read_model, service: TradeTariffBackend.service, region:)
    expect(SearchAnalytics::ReadModelRefresh).to receive(:call).with(region:)
    worker.perform
  end

  it 'does not activate maintenance for another service' do
    other = TradeTariffBackend.service == 'uk' ? 'xi' : 'uk'
    create(:search_analytics_read_model, service: other, region:)
    expect(SearchAnalytics::ReadModelRefresh).not_to receive(:call)
    worker.perform
  end

  it 'leaves an existing refresh alone when the advisory lock is occupied' do
    create(:search_analytics_read_model, service: TradeTariffBackend.service, region:)
    allow(SearchAnalytics::ReadModelRefresh).to receive(:call).and_raise(Sequel::AdvisoryLockError)
    expect { worker.perform }.not_to raise_error
  end

  it 'does not hide a database failure' do
    create(:search_analytics_read_model, service: TradeTariffBackend.service, region:)
    allow(SearchAnalytics::ReadModelRefresh).to receive(:call).and_raise(Sequel::DatabaseError, 'failed')
    expect { worker.perform }.to raise_error(Sequel::DatabaseError, 'failed')
  end

  it 'uses the batch queue without automatic retries' do
    expect(described_class.get_sidekiq_options).to include('queue' => :within_1_day, 'retry' => false)
  end
end

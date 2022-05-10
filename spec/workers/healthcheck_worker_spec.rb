RSpec.describe HealthcheckWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    subject(:healthcheck_key) do
      Sidekiq.redis { |r| r.get 'sidekiq-healthcheck' }
    end

    before do
      freeze_time

      worker.perform
    end

    it 'updates the healthcheck key' do
      expect(healthcheck_key).to eql Time.zone.now.utc.iso8601
    end
  end
end

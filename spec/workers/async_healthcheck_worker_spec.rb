RSpec.describe AsyncHealthcheckWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    before do
      freeze_time

      allow(Rails.cache).to receive(:write)

      worker.perform
    end

    it 'updates the healthcheck key' do
      expect(Rails.cache).to have_received(:write).with(
        'sidekiq-healthcheck',
        Time.zone.now.utc.to_formatted_s(:db),
        expires_in: 1.month.from_now,
      )
    end
  end
end

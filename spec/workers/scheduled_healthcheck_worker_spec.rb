RSpec.describe ScheduledHealthcheckWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    before do
      allow(Sidekiq::Client).to receive(:enqueue)

      worker.perform
    end

    it { expect(Sidekiq::Client).to have_received(:enqueue).with(AsyncHealthcheckWorker) }
  end
end

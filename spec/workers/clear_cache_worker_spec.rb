RSpec.describe ClearCacheWorker, type: :worker do
  subject(:worker) { described_class.new }

  before do
    allow(Rails.cache).to receive(:clear)
    allow(Sidekiq::Client).to receive(:enqueue)

    silence do
      worker.perform
    end
  end

  it { expect(Rails.cache).to have_received(:clear) }
  it { expect(Sidekiq::Client).to have_received(:enqueue).with(PrecacheHeadingsWorker, Time.zone.today.to_s) }
  it { expect(Sidekiq::Client).to have_received(:enqueue).with(PrewarmQuotaOrderNumbersWorker) }
  it { expect(Sidekiq::Client).to have_received(:enqueue).with(ReindexModelsWorker) }
  it { expect(Sidekiq::Client).to have_received(:enqueue).with(InvalidateCacheWorker) }
end

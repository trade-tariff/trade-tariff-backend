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
  it { expect(Sidekiq::Client).to have_received(:enqueue).with(PrewarmSubheadingsWorker) }
  it { expect(Sidekiq::Client).to have_received(:enqueue).with(RecacheModelsWorker) }
  it { expect(Sidekiq::Client).to have_received(:enqueue).with(ReindexModelsWorker) }
end

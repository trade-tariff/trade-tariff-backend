RSpec.describe ClearAllCachesWorker, type: :worker do
  before do
    allow(Rails.cache).to receive(:clear).and_call_original
    allow(TradeTariffBackend.frontend_redis).to receive(:flushdb).and_call_original

    silence { described_class.new.perform }
  end

  it { expect(Rails.cache).to have_received(:clear) }
  it { expect(TradeTariffBackend.frontend_redis).to have_received(:flushdb) }
end

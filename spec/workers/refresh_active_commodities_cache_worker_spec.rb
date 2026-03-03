RSpec.describe RefreshActiveCommoditiesCacheWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    let(:active) { [[1, '0101210000'], [2, '0101290000']] }
    let(:expired) { [[3, '0101210000'], [4, '0201100000']] }

    before do
      allow(Api::User::ActiveCommoditiesService).to receive_messages(
        refresh_caches: nil,
        all_active_commodities: active,
        all_expired_commodities: expired,
      )
      allow(CachedCommodityDescriptionService).to receive(:fetch_for_codes)
    end

    it 'refreshes active commodities caches first' do
      worker.perform

      expect(Api::User::ActiveCommoditiesService).to have_received(:refresh_caches)
    end

    it 'fetches and caches descriptions for all active and expired codes' do
      worker.perform

      expect(CachedCommodityDescriptionService).to have_received(:fetch_for_codes)
        .with(%w[0101210000 0101290000 0201100000])
    end
  end
end

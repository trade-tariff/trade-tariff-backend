RSpec.describe TariffKnowledge::PublicAtarSearchRefresh do
  describe '.call' do
    let(:search_client) { object_double(TradeTariffBackend.search_client, bulk: true, search_operation_options: { refresh: true }) }

    before do
      allow(TradeTariffBackend).to receive(:search_client).and_return(search_client)
      allow(ScoreLabelBatchWorker).to receive(:perform_async)
    end

    it 'indexes matching goods nomenclatures and queues embedding regeneration' do
      commodity = create(:commodity, :with_description, :declarable, goods_nomenclature_item_id: '6302100000')
      create(:goods_nomenclature_self_text,
             goods_nomenclature: commodity,
             goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
             self_text: 'Bed linen')

      result = described_class.call(%w[6302100000])

      expect(result).to eq([commodity.goods_nomenclature_sid])
      expect(search_client).to have_received(:bulk) do |args|
        expect(args).to include(refresh: true)
        operation = args.fetch(:body).first.fetch(:index)
        expect(operation[:_id]).to eq(commodity.goods_nomenclature_sid)
        expect(operation[:data]).to include('goods_nomenclature_sid' => commodity.goods_nomenclature_sid)
      end
      expect(ScoreLabelBatchWorker).to have_received(:perform_async).with([commodity.goods_nomenclature_sid])
    end

    it 'does nothing when no goods nomenclatures match' do
      result = described_class.call(%w[9999999999])

      expect(result).to eq([])
      expect(search_client).not_to have_received(:bulk)
      expect(ScoreLabelBatchWorker).not_to have_received(:perform_async)
    end

    it 'deduplicates blank and repeated item ids before refreshing' do
      commodity = create(:commodity, :with_description, :declarable, goods_nomenclature_item_id: '6302100000')

      result = described_class.call(['6302100000', '', nil, '6302100000'])

      expect(result).to eq([commodity.goods_nomenclature_sid])
      expect(search_client).to have_received(:bulk).once
      expect(ScoreLabelBatchWorker).to have_received(:perform_async).with([commodity.goods_nomenclature_sid])
    end
  end
end

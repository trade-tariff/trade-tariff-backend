RSpec.describe TariffKnowledge::PublicAtarSearchRefresh do
  describe '.call' do
    let(:search_client) { instance_double(TradeTariffBackend::SearchClient, index: true) }

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
      expect(search_client).to have_received(:index).with(Search::GoodsNomenclatureIndex, have_attributes(goods_nomenclature_sid: commodity.goods_nomenclature_sid))
      expect(ScoreLabelBatchWorker).to have_received(:perform_async).with([commodity.goods_nomenclature_sid])
    end

    it 'does nothing when no goods nomenclatures match' do
      result = described_class.call(%w[9999999999])

      expect(result).to eq([])
      expect(search_client).not_to have_received(:index)
      expect(ScoreLabelBatchWorker).not_to have_received(:perform_async)
    end

    it 'deduplicates blank and repeated item ids before refreshing' do
      commodity = create(:commodity, :with_description, :declarable, goods_nomenclature_item_id: '6302100000')

      result = described_class.call(['6302100000', '', nil, '6302100000'])

      expect(result).to eq([commodity.goods_nomenclature_sid])
      expect(search_client).to have_received(:index).once
      expect(ScoreLabelBatchWorker).to have_received(:perform_async).with([commodity.goods_nomenclature_sid])
    end
  end
end

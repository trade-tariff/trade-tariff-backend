RSpec.describe TariffKnowledge::PublicAtarSearchRefresh do
  describe '.call' do
    let(:bulk_response) { { 'errors' => false, 'items' => [{ 'index' => { '_id' => '1', 'status' => 200 } }] } }
    let(:search_client) { object_double(TradeTariffBackend.search_client, bulk: bulk_response, search_operation_options: { refresh: true }) }

    before do
      allow(TradeTariffBackend).to receive(:search_client).and_return(search_client)
      allow(ScoreLabelBatchWorker).to receive(:perform_async)
      allow(AdminConfiguration).to receive(:enabled?).and_call_original
      allow(AdminConfiguration).to receive(:enabled?).with('search_atars_enabled').and_return(true)
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

    context 'when the bulk response reports per item failures' do
      let(:bulk_response) do
        {
          'errors' => true,
          'items' => [
            {
              'index' => {
                '_index' => 'tariff-uk-goods_nomenclatures',
                '_id' => '101',
                'status' => 400,
                'error' => { 'type' => 'mapper_parsing_exception', 'reason' => 'failed to parse field' },
              },
            },
          ],
        }
      end

      it 'raises rather than reporting a successful refresh' do
        create(:commodity, :with_description, :declarable, goods_nomenclature_item_id: '6302100000')

        expect { described_class.call(%w[6302100000]) }.to raise_error(
          TradeTariffBackend::BulkResponse::BulkIndexingError,
          /PublicAtarSearchRefresh.*mapper_parsing_exception.*101/m,
        )
      end

      it 'does not queue embedding regeneration for a batch that failed to index' do
        create(:commodity, :with_description, :declarable, goods_nomenclature_item_id: '6302100000')

        expect { described_class.call(%w[6302100000]) }.to raise_error(TradeTariffBackend::BulkResponse::BulkIndexingError)
        expect(ScoreLabelBatchWorker).not_to have_received(:perform_async)
      end
    end

    context 'when ATaR search is disabled' do
      before do
        allow(AdminConfiguration).to receive(:enabled?).with('search_atars_enabled').and_return(false)
        allow(Rails.logger).to receive(:info)
      end

      it 'skips OpenSearch and embedding refreshes' do
        commodity = create(:commodity, :with_description, :declarable, goods_nomenclature_item_id: '6302100000')

        result = described_class.call([commodity.goods_nomenclature_item_id])

        expect(result).to eq([])
        expect(search_client).not_to have_received(:bulk)
        expect(ScoreLabelBatchWorker).not_to have_received(:perform_async)
        expect(Rails.logger).to have_received(:info).with(
          'Skipping public ATAR search refresh because search_atars_enabled is disabled (1 changed item ID)',
        )
      end
    end
  end
end

RSpec.describe Api::Internal::SearchService do
  describe '#call' do
    let(:opensearch_response) do
      {
        'hits' => {
          'hits' => [
            {
              '_score' => 10.0,
              '_source' => {
                'goods_nomenclature_sid' => declarable.goods_nomenclature_sid,
                'goods_nomenclature_item_id' => declarable.goods_nomenclature_item_id,
                'producline_suffix' => declarable.producline_suffix,
                'goods_nomenclature_class' => declarable.goods_nomenclature_class,
                'description' => 'Live horses',
                'formatted_description' => 'Live horses',
                'full_description' => 'Live horses',
                'declarable' => true,
              },
            },
          ],
        },
      }
    end
    let(:declarable) { create(:commodity, goods_nomenclature_item_id: '0101210000') }

    before do
      allow(AdminConfiguration).to receive(:enabled?).and_call_original
      allow(AdminConfiguration).to receive(:enabled?).with('tariff_knowledge_context_enabled').and_return(true)
      allow(AdminConfiguration).to receive(:option_value).and_call_original
      allow(AdminConfiguration).to receive(:option_value).with('retrieval_method').and_return('opensearch')
      allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      allow(InteractiveSearchService).to receive(:call).and_return(nil)

      TariffKnowledge::DeclarableContext.create(
        goods_nomenclature_sid: declarable.goods_nomenclature_sid,
        goods_nomenclature_item_id: declarable.goods_nomenclature_item_id,
        content: 'Chapter 01 note 1: excludes fish of heading 0301.',
        context_hash: Digest::SHA256.hexdigest('context'),
        generated_at: Time.zone.now,
      )
    end

    it 'passes augmented results to interactive search when enabled' do
      described_class.new(q: 'horse').call

      expect(InteractiveSearchService).to have_received(:call).with(
        hash_including(
          opensearch_results: contain_exactly(
            have_attributes(full_description: include('Tariff note context', 'excludes fish')),
          ),
        ),
      )
    end
  end
end

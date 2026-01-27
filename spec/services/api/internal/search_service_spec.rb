RSpec.describe Api::Internal::SearchService do
  describe '#call' do
    context 'when blank query' do
      it 'returns empty data' do
        result = described_class.new(q: '').call
        expect(result).to eq(data: [])
      end
    end

    context 'when nil query' do
      it 'returns empty data' do
        result = described_class.new(q: nil).call
        expect(result).to eq(data: [])
      end
    end

    context 'when rogue query' do
      it 'returns empty data' do
        result = described_class.new(q: 'gif').call
        expect(result).to eq(data: [])
      end
    end

    context 'when valid query with results' do
      let(:opensearch_response) do
        {
          'hits' => {
            'hits' => [
              {
                '_score' => 12.5,
                '_source' => {
                  'goods_nomenclature_sid' => 1,
                  'goods_nomenclature_item_id' => '0100000000',
                  'producline_suffix' => '80',
                  'goods_nomenclature_class' => 'Chapter',
                  'description' => 'live animals',
                  'formatted_description' => 'Live animals',
                  'declarable' => false,
                },
              },
            ],
          },
        }
      end

      before do
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'returns serialized goods nomenclatures with polymorphic type' do
        result = described_class.new(q: 'animals', as_of: Time.zone.today.iso8601).call

        expect(result[:data].length).to eq(1)
        expect(result[:data][0][:type]).to eq(:chapter)
        expect(result[:data][0][:attributes][:description]).to eq('live animals')
        expect(result[:data][0][:attributes][:score]).to eq(12.5)
      end

      it 'queries the GoodsNomenclatureQuery with processed query and date' do
        described_class.new(q: 'animals', as_of: Time.zone.today.iso8601).call

        expect(TradeTariffBackend.search_client).to have_received(:search).with(
          hash_including(index: Search::GoodsNomenclatureIndex.new.name),
        )
      end
    end

    context 'when valid query with no results' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      before do
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'returns empty data array' do
        result = described_class.new(q: 'nonexistent').call
        expect(result).to eq(data: [])
      end
    end

    context 'when results contain multiple goods nomenclature types' do
      let(:opensearch_response) do
        {
          'hits' => {
            'hits' => [
              {
                '_score' => 10.0,
                '_source' => {
                  'goods_nomenclature_sid' => 1,
                  'goods_nomenclature_item_id' => '0100000000',
                  'producline_suffix' => '80',
                  'goods_nomenclature_class' => 'Chapter',
                  'description' => 'animals',
                  'formatted_description' => 'Animals',
                  'declarable' => false,
                },
              },
              {
                '_score' => 8.0,
                '_source' => {
                  'goods_nomenclature_sid' => 2,
                  'goods_nomenclature_item_id' => '0101000000',
                  'producline_suffix' => '80',
                  'goods_nomenclature_class' => 'Heading',
                  'description' => 'live horses',
                  'formatted_description' => 'Live horses',
                  'declarable' => true,
                },
              },
              {
                '_score' => 6.0,
                '_source' => {
                  'goods_nomenclature_sid' => 3,
                  'goods_nomenclature_item_id' => '0101210000',
                  'producline_suffix' => '80',
                  'goods_nomenclature_class' => 'Commodity',
                  'description' => 'pure-bred breeding animals',
                  'formatted_description' => 'Pure-bred breeding animals',
                  'declarable' => true,
                },
              },
            ],
          },
        }
      end

      before do
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'serializes each result with its type-specific serializer' do
        result = described_class.new(q: 'animals').call

        types = result[:data].map { |d| d[:type] }
        expect(types).to eq(%i[chapter heading commodity])
      end
    end
  end
end

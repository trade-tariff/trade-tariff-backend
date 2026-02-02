RSpec.describe Api::Internal::SearchService do
  before do
    allow(ExpandSearchQueryService).to receive(:call).and_wrap_original do |_method, query|
      ExpandSearchQueryService::Result.new(expanded_query: query, reason: nil)
    end
  end

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

    context 'when exact match via search_reference suggestion' do
      let!(:heading) do
        create(:heading, :with_description,
               goods_nomenclature_item_id: '0101000000',
               description: 'live horses')
      end

      before do
        create(:search_suggestion, :search_reference,
               goods_nomenclature: heading,
               value: 'horse')

        allow(TradeTariffBackend.search_client).to receive(:search)
      end

      it 'returns the exact match without querying OpenSearch' do
        result = described_class.new(q: 'horse').call

        expect(result[:data].length).to eq(1)
        expect(result[:data][0][:type]).to eq(:heading)
        expect(result[:data][0][:attributes][:goods_nomenclature_item_id]).to eq('0101000000')
        expect(result[:data][0][:attributes][:score]).to be_nil
        expect(TradeTariffBackend.search_client).not_to have_received(:search)
      end
    end

    context 'when exact match via singular/plural expansion' do
      let!(:heading) do
        create(:heading, :with_description,
               goods_nomenclature_item_id: '0101000000',
               description: 'live horses')
      end

      before do
        create(:search_suggestion, :search_reference,
               goods_nomenclature: heading,
               value: 'horse')
        allow(TradeTariffBackend.search_client).to receive(:search)
      end

      it 'matches the singular form of a plural query' do
        result = described_class.new(q: 'horses').call

        expect(result[:data].length).to eq(1)
        expect(result[:data][0][:attributes][:goods_nomenclature_item_id]).to eq('0101000000')
        expect(TradeTariffBackend.search_client).not_to have_received(:search)
      end
    end

    context 'when exact match via padded numeric code' do
      let!(:chapter) do
        create(:chapter, :with_description,
               goods_nomenclature_item_id: '0100000000',
               description: 'live animals')
      end

      before do
        create(:search_suggestion, :goods_nomenclature,
               goods_nomenclature: chapter,
               value: '0100000000')

        allow(TradeTariffBackend.search_client).to receive(:search)
      end

      it 'pads short numeric queries to 10 digits' do
        result = described_class.new(q: '01').call

        expect(result[:data].length).to eq(1)
        expect(result[:data][0][:type]).to eq(:chapter)
        expect(result[:data][0][:attributes][:goods_nomenclature_item_id]).to eq('0100000000')
        expect(result[:data][0][:attributes][:score]).to be_nil
        expect(TradeTariffBackend.search_client).not_to have_received(:search)
      end
    end

    context 'when exact match via direct goods nomenclature lookup' do
      before do
        create(:chapter, :with_description,
               goods_nomenclature_item_id: '0100000000',
               description: 'live animals')
        allow(TradeTariffBackend.search_client).to receive(:search)
      end

      it 'falls back to GoodsNomenclature table when no suggestion exists' do
        result = described_class.new(q: '01').call

        expect(result[:data].length).to eq(1)
        expect(result[:data][0][:type]).to eq(:chapter)
        expect(result[:data][0][:attributes][:goods_nomenclature_item_id]).to eq('0100000000')
        expect(TradeTariffBackend.search_client).not_to have_received(:search)
      end
    end

    context 'when exact match skipped for hidden goods nomenclature' do
      let!(:chapter) do
        create(:chapter, :with_description, :hidden,
               goods_nomenclature_item_id: '0100000000',
               description: 'live animals')
      end

      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      before do
        create(:search_suggestion, :goods_nomenclature,
               goods_nomenclature: chapter,
               value: '0100000000')

        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'falls through to OpenSearch instead of returning exact match' do
        described_class.new(q: '01').call

        expect(TradeTariffBackend.search_client).to have_received(:search)
      end
    end

    context 'when suggestion exists but has no associated goods nomenclature' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      before do
        create(:search_suggestion, :goods_nomenclature,
               value: '9999000000',
               goods_nomenclature_sid: 999_999)
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'falls through to OpenSearch' do
        described_class.new(q: '9999').call

        expect(TradeTariffBackend.search_client).to have_received(:search)
      end
    end

    context 'when no exact match and no suggestion' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      before do
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'falls through to OpenSearch for text queries' do
        described_class.new(q: 'nonexistent').call

        expect(TradeTariffBackend.search_client).to have_received(:search)
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

    context 'when expand_search_enabled is false' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }
      let(:classification_scope) { double('classification_scope') } # rubocop:disable RSpec/VerifiedDoubles

      before do
        allow(AdminConfiguration).to receive(:classification).and_return(classification_scope)
        allow(classification_scope).to receive(:by_name).and_return(nil)
        allow(classification_scope).to receive(:by_name)
          .with('expand_search_enabled').and_return(instance_double(AdminConfiguration, value: false))
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'does not call ExpandSearchQueryService' do
        described_class.new(q: 'laptop').call

        expect(ExpandSearchQueryService).not_to have_received(:call)
      end
    end

    context 'when expand_search_enabled is true' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }
      let(:classification_scope) { double('classification_scope') } # rubocop:disable RSpec/VerifiedDoubles

      before do
        allow(AdminConfiguration).to receive(:classification).and_return(classification_scope)
        allow(classification_scope).to receive(:by_name).and_return(nil)
        allow(classification_scope).to receive(:by_name)
          .with('expand_search_enabled').and_return(instance_double(AdminConfiguration, value: true))
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'calls ExpandSearchQueryService' do
        described_class.new(q: 'laptop').call

        expect(ExpandSearchQueryService).to have_received(:call).with('laptop')
      end
    end
  end
end

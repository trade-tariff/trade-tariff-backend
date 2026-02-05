RSpec.describe Api::Internal::SearchService do
  before do
    allow(ExpandSearchQueryService).to receive(:call).and_wrap_original do |_method, query|
      ExpandSearchQueryService::Result.new(expanded_query: query, reason: nil)
    end
    allow(InteractiveSearchService).to receive(:call).and_return(nil)
    allow(Search::Instrumentation).to receive(:search) { |**_kwargs, &block| block.call&.first }
    allow(Search::Instrumentation).to receive(:query_expanded).and_yield
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

      before do
        allow(AdminConfiguration).to receive(:enabled?).and_call_original
        allow(AdminConfiguration).to receive(:enabled?).with('expand_search_enabled').and_return(false)
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'does not call ExpandSearchQueryService' do
        described_class.new(q: 'laptop').call

        expect(ExpandSearchQueryService).not_to have_received(:call)
      end
    end

    context 'when expand_search_enabled is true' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      before do
        allow(AdminConfiguration).to receive(:enabled?).and_call_original
        allow(AdminConfiguration).to receive(:enabled?).with('expand_search_enabled').and_return(true)
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'calls ExpandSearchQueryService' do
        described_class.new(q: 'laptop').call

        expect(ExpandSearchQueryService).to have_received(:call).with('laptop')
      end
    end

    context 'when pos_search_enabled is false' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      before do
        allow(AdminConfiguration).to receive(:enabled?).and_call_original
        allow(AdminConfiguration).to receive(:enabled?).with('pos_search_enabled').and_return(false)
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'passes pos_search: false to GoodsNomenclatureQuery' do
        allow(Search::GoodsNomenclatureQuery).to receive(:new).and_call_original

        described_class.new(q: 'live horses').call

        expect(Search::GoodsNomenclatureQuery).to have_received(:new).with(
          'live horses',
          anything,
          hash_including(pos_search: false),
        )
      end
    end

    context 'when opensearch_result_limit is configured' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      before do
        allow(AdminConfiguration).to receive(:integer_value).and_call_original
        allow(AdminConfiguration).to receive(:integer_value).with('opensearch_result_limit').and_return(50)
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'passes configured size to GoodsNomenclatureQuery' do
        allow(Search::GoodsNomenclatureQuery).to receive(:new).and_call_original

        described_class.new(q: 'horses').call

        expect(Search::GoodsNomenclatureQuery).to have_received(:new).with(
          'horses',
          anything,
          hash_including(size: 50),
        )
      end
    end

    context 'when interactive search returns questions' do
      let(:opensearch_response) do
        {
          'hits' => {
            'hits' => [
              {
                '_score' => 10.0,
                '_source' => {
                  'goods_nomenclature_sid' => 1,
                  'goods_nomenclature_item_id' => '4202210000',
                  'producline_suffix' => '80',
                  'goods_nomenclature_class' => 'Commodity',
                  'description' => 'leather handbags',
                  'formatted_description' => 'Leather handbags',
                  'declarable' => true,
                },
              },
              {
                '_score' => 8.0,
                '_source' => {
                  'goods_nomenclature_sid' => 2,
                  'goods_nomenclature_item_id' => '4202220000',
                  'producline_suffix' => '80',
                  'goods_nomenclature_class' => 'Commodity',
                  'description' => 'plastic handbags',
                  'formatted_description' => 'Plastic handbags',
                  'declarable' => true,
                },
              },
            ],
          },
        }
      end

      let(:interactive_result) do
        InteractiveSearchService::Result.new(
          type: :questions,
          data: [{ question: 'What material?', options: %w[Leather Plastic] }],
          attempt: 1,
          model: 'gpt-5.2',
        )
      end

      before do
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
        allow(InteractiveSearchService).to receive(:call).and_return(interactive_result)
      end

      it 'includes interactive_search in meta with pending question' do
        result = described_class.new(q: 'handbag').call

        expect(result[:meta]).to include(:interactive_search)
        answers = result[:meta][:interactive_search][:answers]
        expect(answers.last[:answer]).to be_nil
      end

      it 'includes request_id in the response' do
        result = described_class.new(q: 'handbag', request_id: 'abc-123').call

        expect(result[:meta][:interactive_search][:request_id]).to eq('abc-123')
      end
    end

    context 'when interactive search returns answers' do
      let(:opensearch_response) do
        {
          'hits' => {
            'hits' => [
              {
                '_score' => 10.0,
                '_source' => {
                  'goods_nomenclature_sid' => 1,
                  'goods_nomenclature_item_id' => '4202210000',
                  'producline_suffix' => '80',
                  'goods_nomenclature_class' => 'Commodity',
                  'description' => 'leather handbags',
                  'formatted_description' => 'Leather handbags',
                  'declarable' => true,
                },
              },
            ],
          },
        }
      end

      let(:interactive_result) do
        InteractiveSearchService::Result.new(
          type: :answers,
          data: [{ commodity_code: '4202210000', confidence: 'strong' }],
          attempt: 2,
          model: 'gpt-5.2',
        )
      end

      before do
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
        allow(InteractiveSearchService).to receive(:call).and_return(interactive_result)
      end

      it 'passes normalized answers to InteractiveSearchService' do
        answers = [{ question: 'Material?', answer: 'Leather' }]
        described_class.new(q: 'handbag', answers: answers).call

        expect(InteractiveSearchService).to have_received(:call).with(
          hash_including(answers: [{ question: 'Material?', options: [], answer: 'Leather' }]),
        )
      end

      it 'includes answers in the response meta' do
        result = described_class.new(q: 'handbag').call

        expect(result[:meta][:interactive_search][:attempt]).to eq(2)
        # No pending question means all questions are answered
        answers = result[:meta][:interactive_search][:answers]
        expect(answers).to be_empty.or(all(satisfy { |a| a[:answer].present? }))
      end
    end

    context 'when interactive search returns nil (disabled or error)' do
      let(:opensearch_response) do
        {
          'hits' => {
            'hits' => [
              {
                '_score' => 10.0,
                '_source' => {
                  'goods_nomenclature_sid' => 1,
                  'goods_nomenclature_item_id' => '4202210000',
                  'producline_suffix' => '80',
                  'goods_nomenclature_class' => 'Commodity',
                  'description' => 'leather handbags',
                  'formatted_description' => 'Leather handbags',
                  'declarable' => true,
                },
              },
            ],
          },
        }
      end

      before do
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
        allow(InteractiveSearchService).to receive(:call).and_return(nil)
      end

      it 'does not include interactive_search in meta' do
        result = described_class.new(q: 'handbag').call

        expect(result[:meta]).to be_nil
      end
    end

    context 'when expanded_query differs from original' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }
      let(:interactive_result) do
        InteractiveSearchService::Result.new(
          type: :error,
          data: { message: 'No search results found' },
          attempt: 1,
          model: 'gpt-5.2',
        )
      end

      before do
        allow(ExpandSearchQueryService).to receive(:call)
          .and_return(ExpandSearchQueryService::Result.new(
                        expanded_query: 'portable data processing machine',
                        reason: 'laptop is colloquial',
                      ))
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
        allow(InteractiveSearchService).to receive(:call).and_return(interactive_result)
      end

      it 'includes expanded_query in interactive_search meta' do
        result = described_class.new(q: 'laptop').call

        expect(result[:meta][:interactive_search]).to include(expanded_query: 'portable data processing machine')
      end
    end
  end
end

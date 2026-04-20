RSpec.describe Api::Internal::SearchService do
  before do
    allow(AdminConfiguration).to receive(:option_value).and_call_original
    allow(AdminConfiguration).to receive(:option_value).with('retrieval_method').and_return('opensearch')
    allow(ExpandSearchQueryService).to receive(:call).and_wrap_original do |_method, query|
      ExpandSearchQueryService::Result.new(expanded_query: query, reason: nil)
    end
    allow(InteractiveSearchService).to receive(:call).and_return(nil)
    allow(Search::Instrumentation).to receive(:search) { |**_kwargs, &block| block.call&.first }
    allow(Search::Instrumentation).to receive(:query_expanded).and_yield
    allow(Search::Instrumentation).to receive(:description_intercept_checked)
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

    context 'when exact match via search_reference suggestion' do
      let!(:heading) do
        create(:heading, :with_description,
               goods_nomenclature_item_id: '0101000000',
               description: 'live horses')
      end

      before do
        create(:search_suggestion, :search_reference,
               goods_nomenclature: heading,
               value: 'horse',
               declarable: true)

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
               value: 'horse',
               declarable: true)
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
               value: '0100000000',
               declarable: true)

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
               value: '0100000000',
               declarable: true)

        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'falls through to OpenSearch instead of returning exact match' do
        described_class.new(q: '01').call

        expect(TradeTariffBackend.search_client).to have_received(:search)
      end
    end

    context 'when exact match is in a configured excluded chapter' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      before do
        create(:admin_configuration,
               name: 'interactive_search_excluded_chapters',
               config_type: 'multi_options',
               area: 'classification',
               value: {
                 'selected' => %w[98],
                 'options' => [
                   { 'key' => '98', 'label' => 'Chapter 98' },
                   { 'key' => '99', 'label' => 'Chapter 99' },
                 ],
               })
        create(:chapter, :with_description,
               goods_nomenclature_item_id: '9800000000',
               description: 'special classifications')
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'falls through to OpenSearch instead of returning exact match' do
        result = described_class.new(q: '98').call

        expect(result).to eq(data: [])
        expect(TradeTariffBackend.search_client).to have_received(:search)
      end
    end

    context 'when suggestion exists but has no associated goods nomenclature' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      before do
        create(:search_suggestion, :goods_nomenclature,
               value: '9999000000',
               goods_nomenclature_sid: 999_999,
               declarable: true)
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

      it 'instruments the lack of a description intercept match' do
        described_class.new(q: 'animals', as_of: Time.zone.today.iso8601, request_id: 'req-1').call

        expect(Search::Instrumentation).to have_received(:description_intercept_checked).with(
          request_id: 'req-1',
          query: 'animals',
          description_intercept: nil,
        )
      end
    end

    context 'when description intercept excludes the query' do
      before do
        create(:description_intercept,
               term: 'gift',
               excluded: true,
               message: 'Gift is too vague.',
               guidance_level: 'warning',
               guidance_location: 'interstitial',
               escalate_to_webchat: true)
        allow(TradeTariffBackend.search_client).to receive(:search)
      end

      it 'returns no results with intercept meta without querying retrieval' do
        result = described_class.new(q: 'gift', request_id: 'req-1').call

        expect(result).to include(data: [])
        expect(result[:meta][:description_intercept]).to include(
          term: 'gift',
          excluded: true,
          filtering: false,
          filter_prefixes: [],
          message: 'Gift is too vague.',
          guidance_level: 'warning',
          guidance_location: 'interstitial',
          escalate_to_webchat: true,
        )
        expect(TradeTariffBackend.search_client).not_to have_received(:search)
        expect(Search::Instrumentation).to have_received(:description_intercept_checked).with(
          request_id: 'req-1',
          query: 'gift',
          description_intercept: an_instance_of(DescriptionIntercept),
        )
      end
    end

    context 'when description intercept provides guidance' do
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
        create(:description_intercept,
               term: 'animals',
               message: 'Use a more specific animal term.',
               guidance_level: 'info',
               guidance_location: 'results',
               escalate_to_webchat: true)
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'keeps results and adds intercept meta' do
        result = described_class.new(q: 'animals').call

        expect(result[:data].length).to eq(1)
        expect(result[:meta][:description_intercept]).to include(
          term: 'animals',
          excluded: false,
          filtering: false,
          message: 'Use a more specific animal term.',
          guidance_level: 'info',
          guidance_location: 'results',
          escalate_to_webchat: true,
        )
      end

      it 'adds description intercept fields to search completion instrumentation' do
        completion_payload = nil
        allow(Search::Instrumentation).to receive(:search) do |**_kwargs, &block|
          result, completion_payload = block.call
          result
        end

        described_class.new(q: 'animals').call

        expect(completion_payload[:description_intercept]).to have_attributes(
          term: 'animals',
          excluded: false,
          filtering?: false,
          filter_prefixes_array: [],
          guidance_level: 'info',
          guidance_location: 'results',
          escalate_to_webchat: true,
        )
      end
    end

    context 'when description intercept filters the query' do
      before do
        create(:description_intercept,
               term: 'toy',
               message: nil,
               guidance_level: nil,
               guidance_location: nil,
               filter_prefixes: Sequel.pg_array(%w[9503 9504], :text))
        allow(OpensearchRetrievalService).to receive(:call).and_return(
          OpensearchRetrievalService::Result.new(results: [], expanded_query: 'toy'),
        )
      end

      it 'passes prefixes to retrieval and adds filtering meta' do
        result = described_class.new(q: 'toy').call

        expect(OpensearchRetrievalService).to have_received(:call).with(
          hash_including(filter_prefixes: %w[9503 9504]),
        )
        expect(result[:meta][:description_intercept]).to include(
          term: 'toy',
          filtering: true,
          filter_prefixes: %w[9503 9504],
        )
      end
    end

    context 'when filtered description intercept has an exact match outside prefixes' do
      let!(:chapter) do
        create(:chapter, :with_description,
               goods_nomenclature_item_id: '0100000000',
               description: 'live animals')
      end

      before do
        create(:description_intercept,
               term: 'animals',
               filter_prefixes: Sequel.pg_array(%w[9503], :text))
        create(:search_suggestion, :goods_nomenclature,
               goods_nomenclature: chapter,
               value: 'animals',
               declarable: true)
        allow(OpensearchRetrievalService).to receive(:call).and_return(
          OpensearchRetrievalService::Result.new(results: [], expanded_query: 'animals'),
        )
      end

      it 'does not let the exact match bypass filtering' do
        result = described_class.new(q: 'animals').call

        expect(result[:data]).to be_empty
        expect(OpensearchRetrievalService).to have_received(:call).with(
          hash_including(filter_prefixes: %w[9503]),
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

    context 'when exact match via synonym suggestion with suggest_synonyms enabled' do
      let!(:heading) do
        create(:heading, :with_description,
               goods_nomenclature_item_id: '1006000000',
               description: 'rice')
      end

      before do
        create(:search_suggestion, :synonym,
               goods_nomenclature: heading,
               value: 'rice',
               declarable: true)

        allow(AdminConfiguration).to receive(:enabled?).and_call_original
        allow(AdminConfiguration).to receive(:enabled?).with('suggest_synonyms').and_return(true)
        allow(TradeTariffBackend.search_client).to receive(:search)
      end

      it 'returns the exact match without querying OpenSearch' do
        result = described_class.new(q: 'rice').call

        expect(result[:data].length).to eq(1)
        expect(result[:data][0][:attributes][:goods_nomenclature_item_id]).to eq('1006000000')
        expect(TradeTariffBackend.search_client).not_to have_received(:search)
      end
    end

    context 'when exact match via synonym suggestion with suggest_synonyms disabled' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      before do
        heading = create(:heading, :with_description,
                         goods_nomenclature_item_id: '1006000000',
                         description: 'rice')

        create(:search_suggestion, :synonym,
               goods_nomenclature: heading,
               value: 'rice',
               declarable: true)

        allow(AdminConfiguration).to receive(:enabled?).and_call_original
        allow(AdminConfiguration).to receive(:enabled?).with('suggest_synonyms').and_return(false)
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'skips the synonym and falls through to OpenSearch' do
        described_class.new(q: 'rice').call

        expect(TradeTariffBackend.search_client).to have_received(:search)
      end
    end

    context 'when exact match suggestion is non-declarable' do
      let!(:heading) do
        create(:heading, :with_description,
               goods_nomenclature_item_id: '0101000000',
               description: 'live horses')
      end

      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      before do
        create(:search_suggestion, :search_reference,
               goods_nomenclature: heading,
               value: 'horse',
               declarable: false)

        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'falls through to OpenSearch instead of returning an exact match' do
        result = described_class.new(q: 'horse').call

        expect(result).to eq(data: [])
        expect(TradeTariffBackend.search_client).to have_received(:search)
      end
    end

    context 'when query contains HTML tags' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      before do
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'sanitises the query before searching' do
        allow(Search::GoodsNomenclatureQuery).to receive(:new).and_call_original

        described_class.new(q: '<b>shoes</b>').call

        expect(Search::GoodsNomenclatureQuery).to have_received(:new).with(
          'shoes',
          anything,
          anything,
        )
      end
    end

    context 'when query exceeds max length' do
      it 'returns errors hash without searching' do
        allow(TradeTariffBackend.search_client).to receive(:search)

        result = described_class.new(q: 'a' * 501).call

        expect(result[:errors]).to be_present
        expect(result[:errors].first[:status]).to eq('422')
        expect(TradeTariffBackend.search_client).not_to have_received(:search)
      end
    end

    context 'when input_sanitiser_enabled is false' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      before do
        allow(AdminConfiguration).to receive(:enabled?).and_call_original
        allow(AdminConfiguration).to receive(:enabled?).with('input_sanitiser_enabled').and_return(false)
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'skips sanitisation and passes query directly to process_query' do
        allow(Search::GoodsNomenclatureQuery).to receive(:new).and_call_original

        described_class.new(q: 'red shoes').call

        expect(Search::GoodsNomenclatureQuery).to have_received(:new).with(
          'red shoes',
          anything,
          anything,
        )
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

    context 'when retrieval_method is vector' do
      let(:vector_results) do
        [
          OpenStruct.new(
            id: 1,
            goods_nomenclature_item_id: '0101210000',
            goods_nomenclature_sid: 1,
            producline_suffix: '80',
            goods_nomenclature_class: 'Commodity',
            description: 'pure-bred breeding horses',
            formatted_description: 'Pure-bred breeding horses',
            self_text: 'Pure-bred breeding horses',
            classification_description: 'Pure-bred breeding horses',
            full_description: 'Pure-bred breeding horses',
            heading_description: nil,
            declarable: true,
            score: 0.95,
            confidence: nil,
          ),
        ]
      end

      before do
        allow(AdminConfiguration).to receive(:option_value).and_call_original
        allow(AdminConfiguration).to receive(:option_value).with('retrieval_method').and_return('vector')
        allow(VectorRetrievalService).to receive(:call).and_return(vector_results)
      end

      it 'skips query expansion' do
        described_class.new(q: 'horses').call

        expect(ExpandSearchQueryService).not_to have_received(:call)
      end

      it 'calls VectorRetrievalService with query' do
        described_class.new(q: 'horses').call

        expect(VectorRetrievalService).to have_received(:call).with(
          hash_including(query: 'horses'),
        )
      end

      it 'does not call OpenSearch' do
        allow(TradeTariffBackend.search_client).to receive(:search)

        described_class.new(q: 'horses').call

        expect(TradeTariffBackend.search_client).not_to have_received(:search)
      end

      it 'returns serialized results' do
        result = described_class.new(q: 'horses').call

        expect(result[:data].length).to eq(1)
        expect(result[:data][0][:attributes][:goods_nomenclature_item_id]).to eq('0101210000')
      end

      context 'with a filtering description intercept' do
        before do
          create(:description_intercept,
                 term: 'horses',
                 filter_prefixes: Sequel.pg_array(%w[0101], :text))
        end

        it 'passes prefixes to VectorRetrievalService' do
          described_class.new(q: 'horses').call

          expect(VectorRetrievalService).to have_received(:call).with(
            hash_including(filter_prefixes: %w[0101]),
          )
        end
      end
    end

    context 'when retrieval_method is hybrid' do
      let(:hybrid_results) do
        [
          OpenStruct.new(
            id: 1,
            goods_nomenclature_item_id: '0101210000',
            goods_nomenclature_sid: 1,
            producline_suffix: '80',
            goods_nomenclature_class: 'Commodity',
            description: 'pure-bred breeding horses',
            formatted_description: 'Pure-bred breeding horses',
            self_text: 'Pure-bred breeding horses',
            classification_description: 'Pure-bred breeding horses',
            full_description: 'Pure-bred breeding horses',
            heading_description: nil,
            declarable: true,
            score: 0.032,
            confidence: nil,
          ),
        ]
      end

      let(:hybrid_result) do
        HybridRetrievalService::Result.new(
          results: hybrid_results,
          expanded_query: 'expanded horses',
        )
      end

      before do
        allow(AdminConfiguration).to receive(:option_value).and_call_original
        allow(AdminConfiguration).to receive(:option_value).with('retrieval_method').and_return('hybrid')
        allow(HybridRetrievalService).to receive(:call).and_return(hybrid_result)
      end

      it 'calls HybridRetrievalService' do
        described_class.new(q: 'horses').call

        expect(HybridRetrievalService).to have_received(:call).with(
          hash_including(query: 'horses'),
        )
      end

      it 'does not call OpenSearch directly' do
        allow(TradeTariffBackend.search_client).to receive(:search)

        described_class.new(q: 'horses').call

        expect(TradeTariffBackend.search_client).not_to have_received(:search)
      end

      it 'returns serialized results' do
        result = described_class.new(q: 'horses').call

        expect(result[:data].length).to eq(1)
        expect(result[:data][0][:attributes][:goods_nomenclature_item_id]).to eq('0101210000')
      end

      context 'with a filtering description intercept' do
        before do
          create(:description_intercept,
                 term: 'horses',
                 filter_prefixes: Sequel.pg_array(%w[0101], :text))
        end

        it 'passes prefixes to HybridRetrievalService' do
          described_class.new(q: 'horses').call

          expect(HybridRetrievalService).to have_received(:call).with(
            hash_including(filter_prefixes: %w[0101]),
          )
        end
      end
    end

    context 'when expanded_query differs from original' do
      let(:opensearch_response) do
        {
          'hits' => {
            'hits' => [
              {
                '_score' => 10.0,
                '_source' => {
                  'goods_nomenclature_sid' => 1,
                  'goods_nomenclature_item_id' => '8471300000',
                  'producline_suffix' => '80',
                  'goods_nomenclature_class' => 'Commodity',
                  'description' => 'portable data processing machine',
                  'formatted_description' => 'Portable data processing machine',
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
          data: [{ question: 'What type of laptop?', options: %w[Personal Business] }],
          attempt: 1,
          model: 'gpt-5.2',
          result_limit: 5,
        )
      end

      before do
        allow(AdminConfiguration).to receive(:enabled?).and_call_original
        allow(AdminConfiguration).to receive(:enabled?).with('expand_search_enabled').and_return(true)
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

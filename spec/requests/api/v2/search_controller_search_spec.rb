RSpec.describe Api::V2::SearchController do
  describe 'GET /search' do
    subject(:api_response) do
      make_request
      response
    end

    let(:make_request) do
      get '/uk/api/search', params: { q: chapter.to_param, as_of: chapter.validity_start_date }, headers: request_headers
    end

    let(:chapter) { create :chapter }

    it { is_expected.to have_http_status(:ok) }
  end

  describe 'POST /search' do
    it 'sets the search request id from the request params' do
      allow(Search::Instrumentation).to receive(:search).and_call_original

      post '/uk/api/search', params: { q: 'horse', request_id: 'param-request-id' }, headers: request_headers, as: :json

      expect(Search::Instrumentation).to have_received(:search).with(
        request_id: 'param-request-id',
        query: 'horse',
        search_type: 'classic',
      )
    end

    context 'when an exact match' do
      before do
        goods_nomenclature = create :chapter, goods_nomenclature_item_id: '0100000000'

        create(:search_suggestion, :goods_nomenclature, goods_nomenclature:)

        post '/uk/api/search', params: { q: '01', as_of: Time.zone.today.iso8601 }, headers: request_headers, as: :json
      end

      let(:pattern) do
        {
          data: {
            id: String,
            type: 'exact_search',
            attributes: {
              type: 'exact_match',
              entry: {
                endpoint: 'chapters',
                id: '01',
              },
            },
          },
        }
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(response.body).to match_json_expression(pattern) }
    end

    context 'when fuzzy matching' do
      before do
        post '/uk/api/search', params: { q: chapter.description, as_of: chapter.validity_start_date }, headers: request_headers, as: :json
      end

      let(:chapter) { create :chapter, :with_description, description: 'horse', validity_start_date: Time.zone.today }

      let(:pattern) do
        {
          data: {
            id: String,
            type: 'fuzzy_search',
            attributes: {
              type: 'fuzzy_match',
              reference_match: {
                commodities: Array,
                headings: Array,
                chapters: Array,
              },
              goods_nomenclature_match: {
                commodities: Array,
                headings: Array,
                chapters: Array,
              },
            },
          },
        }
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(response.body).to match_json_expression(pattern) }
    end

    context 'when no matches are found' do
      before { post '/uk/api/search', headers: request_headers, as: :json }

      let(:pattern) do
        {
          data: {
            id: String,
            type: 'null_search',
            attributes: {
              type: 'null_match',
              reference_match: {
                commodities: [],
                headings: [],
                chapters: [],
              },
              goods_nomenclature_match: {
                commodities: [],
                headings: [],
                chapters: [],
              },
            },
          },
        }
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(response.body).to match_json_expression(pattern) }
    end

    context 'when measuring classic result metrics' do
      subject(:metrics) { controller.send(:classic_result_metrics, results) }

      let(:controller) { described_class.new }

      context 'with fuzzy headings but no commodities' do
        let(:results) do
          {
            data: {
              type: :fuzzy_search,
              attributes: {
                goods_nomenclature_match: {
                  'headings' => [{ '_score' => 10.0, '_source' => { 'goods_nomenclature_item_id' => '0101000000' } }],
                  'chapters' => [],
                  'commodities' => [],
                  'sections' => [{ '_score' => 1.0 }],
                },
                reference_match: {
                  'chapters' => [{ '_score' => 8.0, '_source' => { 'goods_nomenclature_item_id' => '0100000000' } }],
                  'headings' => [],
                  'commodities' => [],
                  'sections' => [],
                },
              },
            },
          }
        end

        it 'counts hits by tariff level' do
          expect(metrics).to include(
            result_count: 3,
            chapter_result_count: 1,
            heading_result_count: 1,
            commodity_result_count: 0,
            other_result_count: 1,
            results_type: :fuzzy_search,
          )
        end
      end

      context 'with fuzzy commodity hits' do
        let(:results) do
          {
            data: {
              type: :fuzzy_search,
              attributes: {
                goods_nomenclature_match: {
                  'commodities' => [
                    { '_score' => 12.0, '_source' => { 'goods_nomenclature_item_id' => '0101210000' } },
                  ],
                  'headings' => [],
                  'chapters' => [],
                },
                reference_match: {
                  'commodities' => [
                    { '_score' => 9.0, '_source' => { 'goods_nomenclature_item_id' => '0101290000' } },
                  ],
                  'headings' => [],
                  'chapters' => [],
                },
              },
            },
          }
        end

        it 'counts commodity hits in both total and commodity metrics' do
          expect(metrics).to include(
            result_count: 2,
            chapter_result_count: 0,
            heading_result_count: 0,
            commodity_result_count: 2,
            other_result_count: 0,
          )
        end
      end

      context 'with an exact search' do
        let(:results) do
          {
            data: {
              type: :exact_search,
              attributes: {
                type: 'exact_match',
                entry: { endpoint: 'commodities', id: '0101210000' },
              },
            },
          }
        end

        it 'attributes the exact match to the target endpoint level' do
          expect(metrics).to include(
            result_count: 1,
            chapter_result_count: 0,
            heading_result_count: 0,
            commodity_result_count: 1,
            other_result_count: 0,
          )
        end
      end

      context 'with an exact chapter search' do
        let(:results) do
          {
            data: {
              type: :exact_search,
              attributes: {
                type: 'exact_match',
                entry: { endpoint: 'chapters', id: '01' },
              },
            },
          }
        end

        it 'attributes the exact match to chapter_result_count' do
          expect(metrics).to include(
            result_count: 1,
            chapter_result_count: 1,
            heading_result_count: 0,
            commodity_result_count: 0,
            other_result_count: 0,
          )
        end
      end

      context 'with an exact heading search' do
        let(:results) do
          {
            data: {
              type: :exact_search,
              attributes: {
                type: 'exact_match',
                entry: { endpoint: 'headings', id: '0101' },
              },
            },
          }
        end

        it 'attributes the exact match to heading_result_count' do
          expect(metrics).to include(
            result_count: 1,
            chapter_result_count: 0,
            heading_result_count: 1,
            commodity_result_count: 0,
            other_result_count: 0,
          )
        end
      end

      context 'with an exact subheading search' do
        let(:results) do
          {
            data: {
              type: :exact_search,
              attributes: {
                type: 'exact_match',
                entry: { endpoint: 'subheadings', id: '0101210000-80' },
              },
            },
          }
        end

        it 'counts subheadings with commodities for product-quality metrics' do
          expect(metrics).to include(
            result_count: 1,
            chapter_result_count: 0,
            heading_result_count: 0,
            commodity_result_count: 1,
            other_result_count: 0,
          )
        end
      end

      context 'with an exact search to an unknown endpoint' do
        let(:results) do
          {
            data: {
              type: :exact_search,
              attributes: {
                type: 'exact_match',
                entry: { endpoint: 'sections', id: '1' },
              },
            },
          }
        end

        it 'buckets the match into other_result_count' do
          expect(metrics).to include(
            result_count: 1,
            chapter_result_count: 0,
            heading_result_count: 0,
            commodity_result_count: 0,
            other_result_count: 1,
          )
        end
      end

      context 'with a non-hash payload' do
        let(:results) { 'not a search payload' }

        it 'returns zeroed level counts so logs always expose the fields' do
          expect(metrics).to eq(
            result_count: 0,
            chapter_result_count: 0,
            heading_result_count: 0,
            commodity_result_count: 0,
            other_result_count: 0,
          )
        end
      end

      context 'with empty fuzzy arrays' do
        let(:results) do
          {
            data: {
              type: :fuzzy_search,
              attributes: {
                goods_nomenclature_match: {
                  'chapters' => [],
                  'headings' => [],
                  'commodities' => [],
                  'sections' => [],
                },
                reference_match: {
                  'chapters' => [],
                  'headings' => [],
                  'commodities' => [],
                  'sections' => [],
                },
              },
            },
          }
        end

        it 'returns zero totals and zero level counts' do
          expect(metrics).to include(
            result_count: 0,
            chapter_result_count: 0,
            heading_result_count: 0,
            commodity_result_count: 0,
            other_result_count: 0,
            results_type: :fuzzy_search,
          )
        end
      end
    end
  end

  describe 'GET /search_suggestions' do
    context 'when a query is provided' do
      subject(:api_response) do
        make_request
        response
      end

      let(:make_request) do
        get '/uk/api/search_suggestions', params: { q: 'same' }, headers: request_headers
      end

      let(:pattern) do
        {
          'data' => [
            {
              'id' => be_present,
              'type' => 'search_suggestion',
              'attributes' => {
                'value' => 'same',
                'score' => 1.0,
                'query' => 'same',
                'suggestion_type' => 'search_reference',
                'priority' => 1,
                'goods_nomenclature_class' => 'Heading',
              },
            },
          ],
        }
      end

      before do
        create(:search_suggestion, :search_reference, value: 'same')
        create(:search_suggestion, :search_reference, value: 'but different')
      end

      it { expect(api_response.body).to match_json_expression pattern }

      it_behaves_like 'a successful jsonapi response'
    end

    context 'when no query is provided' do
      subject(:api_response) do
        make_request
        response
      end

      let(:make_request) do
        get '/uk/api/search_suggestions', headers: request_headers
      end

      it_behaves_like 'a successful jsonapi response'
    end
  end
end

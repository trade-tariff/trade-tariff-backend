RSpec.describe Api::V2::BulkSearchesController, type: :request do
  describe 'POST /bulk_searches' do
    subject(:do_post) { make_request && response }

    let(:make_request) do
      params = { data: [{ type: 'searches', attributes: { input_description: '1234' } }] }

      post '/bulk_searches', params:
    end

    let(:pattern) do
      {
        data: {
          id: /\A[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/i,
          type: 'result_collection',
          attributes: {
            status: 'queued',
            message: 'Your bulk search request has been accepted and is now on a queue waiting to be processed',
          },
          relationships: {
            searches: { data: [{ id: String, type: 'search' }] },
          },
        },
      }
    end

    let(:id) { JSON.parse(response.body).dig('data', 'id') }

    before do
      allow(BulkSearch::ResultCollection).to receive(:enqueue).and_call_original

      do_post
    end

    it { expect(BulkSearch::ResultCollection).to have_received(:enqueue) }
    it { expect(response).to have_http_status(:accepted) }
    it { expect(response.body).to match_json_expression(pattern) }
    it { expect(response.location).to eq(api_bulk_search_path(id)) }
  end

  describe 'GET /bulk_searches/:id' do
    subject(:do_get) { make_request && response }

    let(:make_request) do
      get "/bulk_searches/#{uuid}"
    end

    let(:uuid) { SecureRandom.uuid }
    let(:json_blob) do
      {
        id: uuid,
        status:,
        searches: [],
      }.to_json
    end

    context 'when there is no corresponding bulk search job' do
      it { expect { do_get }.to raise_error(BulkSearch::ResultCollection::RecordNotFound) }
    end

    context 'when the bulk search job is still queued' do
      before do
        TradeTariffBackend.redis.set(uuid, Zlib::Deflate.deflate(json_blob))

        do_get
      end

      let(:status) { 'queued' }

      let(:pattern) do
        {
          data: {
            id: uuid,
            type: 'result_collection',
            attributes: {
              status: 'queued',
              message: 'Your bulk search request has been accepted and is now on a queue waiting to be processed',
            },
            relationships: {
              searches: { data: [] },
            },
          },
          included: [],
        }
      end

      it { expect(response).to have_http_status(:accepted) }
      it { expect(response.body).to match_json_expression(pattern) }
    end

    context 'when the bulk search job is processing' do
      before do
        TradeTariffBackend.redis.set(uuid, Zlib::Deflate.deflate(json_blob))

        do_get
      end

      let(:status) { 'processing' }

      let(:pattern) do
        {
          data: {
            id: uuid,
            type: 'result_collection',
            attributes: {
              status: 'processing',
              message: 'Processing',
            },
            relationships: {
              searches: { data: [] },
            },
          },
          included: [],
        }
      end

      it { expect(response).to have_http_status(:accepted) }
      it { expect(response.body).to match_json_expression(pattern) }
    end

    context 'when the bulk search job has completed' do
      before do
        TradeTariffBackend.redis.set(uuid, Zlib::Deflate.deflate(json_blob))

        do_get
      end

      let(:status) { 'completed' }

      let(:pattern) do
        {
          data: {
            id: uuid,
            type: 'result_collection',
            attributes: {
              status: 'completed',
              message: 'Completed',
            },
            relationships: {
              searches: { data: [] },
            },
          },
          included: [],
        }
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(response.body).to match_json_expression(pattern) }
    end

    context 'when the bulk search job has failed' do
      before do
        TradeTariffBackend.redis.set(uuid, Zlib::Deflate.deflate(json_blob))

        do_get
      end

      let(:status) { 'failed' }

      let(:pattern) do
        {
          data: {
            id: uuid,
            type: 'result_collection',
            attributes: {
              status: 'failed',
              message: 'Failed',
            },
            relationships: {
              searches: { data: [] },
            },
          },
          included: [],
        }
      end

      it { expect(response).to have_http_status(:internal_server_error) }
      it { expect(response.body).to match_json_expression(pattern) }
    end
  end
end
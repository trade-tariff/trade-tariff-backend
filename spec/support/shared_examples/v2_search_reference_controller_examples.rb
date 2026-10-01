RSpec.shared_examples_for 'v2 search references controller' do
  before do
    allow(ScoreLabelBatchWorker).to receive(:perform_async)
    search_reference
  end

  let(:search_reference_resource_path) do
    "#{search_references_collection_path.delete_suffix('.json')}/#{resource_query.fetch(:id)}.json"
  end

  describe 'GET #index' do
    let(:pattern) do
      {
        data: [
          {
            id: String,
            type: 'search_reference',
            attributes: {
              title: String,
              referenced_id: String,
              referenced_class: String,
              goods_nomenclature_item_id: String,
              productline_suffix: String,
              goods_nomenclature_sid: Integer,
              usage: 'search',
            },
          },
        ],
      }
    end

    context 'without pagination' do
      it 'returns rendered records with default pagination values' do
        get search_references_collection_path, headers: request_headers(format: :json)

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'with a usage filter' do
      before do
        create :search_reference, referenced: search_reference.referenced, title: 'fpo only', usage: 'fpo'
      end

      it 'excludes fpo references without a filter' do
        get search_references_collection_path, headers: request_headers(format: :json)

        expect(JSON.parse(response.body)['data'].map { |ref| ref.dig('attributes', 'usage') }).to eq(%w[search])
      end

      it 'returns every usage with the all filter' do
        get search_references_collection_path, params: { filter: { usage: 'all' } }, headers: request_headers(format: :json)

        expect(JSON.parse(response.body)['data'].map { |ref| ref.dig('attributes', 'usage') }).to contain_exactly('search', 'fpo')
      end

      it 'returns only references with the requested usage' do
        get search_references_collection_path, params: { filter: { usage: 'fpo' } }, headers: request_headers(format: :json)

        expect(JSON.parse(response.body)['data'].map { |ref| ref.dig('attributes', 'title') }).to eq(['fpo only'])
      end
    end
  end

  describe 'GET to #show' do
    let(:pattern) do
      {
        data:
          {
            id: String,
            type: 'search_reference',
            attributes: {
              title: String,
              referenced_id: String,
              referenced_class: String,
              goods_nomenclature_item_id: String,
              productline_suffix: String,
              goods_nomenclature_sid: Integer,
              usage: 'search',
            },
            relationships: {
              referenced: {
                data: Hash,
              },
            },
          },
        included: [
          {
            id: String,
            type: String,
            attributes: Hash,
          }.ignore_extra_keys!,
        ],
      }
    end

    it 'returns rendered search reference record' do
      get search_reference_resource_path, headers: request_headers(format: :json)

      expect(response.body).to match_json_expression pattern
    end
  end

  describe 'POST to #create' do
    let(:search_reference) { build :search_reference }

    context 'with valid params provided' do
      let(:pattern) do
        {
          data:
            {
              id: String,
              type: 'search_reference',
              attributes: {
                title: String,
                referenced_id: String,
                referenced_class: String,
                goods_nomenclature_item_id: String,
                productline_suffix: String,
                goods_nomenclature_sid: Integer,
                usage: 'search',
              },
              relationships: Hash,
            },
          included: [
            {
              id: String,
              type: String,
              attributes: Hash,
            }.ignore_extra_keys!,
          ],
        }
      end

      before do
        post search_references_collection_path,
             params: { data: { type: :search_reference, attributes: { title: search_reference.title } } },
             headers: request_headers(format: :json),
             as: :json
      end

      it 'persists SearchReference entry' do
        expect(SearchReference.all).not_to be_none
      end

      it 'returns persisted record' do
        expect(response.body).to match_json_expression pattern
      end

      it 'enqueues ScoreLabelBatchWorker' do
        expect(ScoreLabelBatchWorker).to have_received(:perform_async)
      end
    end

    context 'with invalid params provided' do
      let(:pattern) do
        { errors: Array }
      end

      before do
        post search_references_collection_path,
             params: { data: { type: :search_reference, attributes: { title: '' } } },
             headers: request_headers(format: :json),
             as: :json
      end

      it 'does not persist SearchReference entry' do
        expect(SearchReference.all).to be_none
      end

      it 'returns validation errors' do
        expect(response.body).to match_json_expression pattern
      end
    end

    context 'with XLS formulas' do
      let(:pattern) do
        {
          data:
            {
              id: String,
              type: 'search_reference',
              attributes: {
                title: String,
                referenced_id: String,
                referenced_class: String,
                goods_nomenclature_item_id: String,
                productline_suffix: String,
                goods_nomenclature_sid: Integer,
                usage: 'search',
              },
              relationships: Hash,
            },
          included: [
            {
              id: String,
              type: String,
              attributes: Hash,
            }.ignore_extra_keys!,
          ],
        }
      end

      before do
        post search_references_collection_path,
             params: { data: { type: :search_reference, attributes: { title: '=SUM(A1:A2)' } } },
             headers: request_headers(format: :json),
             as: :json
      end

      it 'escapes the formula' do
        expect(SearchReference.first.title).to eq "'=SUM(A1:A2)"
      end
    end

    context 'with an fpo usage' do
      before do
        post search_references_collection_path,
             params: { data: { type: :search_reference, attributes: { title: search_reference.title, usage: 'fpo' } } },
             headers: request_headers(format: :json),
             as: :json
      end

      it 'persists the usage' do
        expect(SearchReference.first.usage).to eq 'fpo'
      end
    end

    context 'with an unknown usage' do
      before do
        post search_references_collection_path,
             params: { data: { type: :search_reference, attributes: { title: search_reference.title, usage: 'other' } } },
             headers: request_headers(format: :json),
             as: :json
      end

      it 'returns unprocessable content' do
        expect(response.status).to eq 422
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'with valid search reference' do
      before { search_reference }

      it 'destroys SearchReference entry' do
        expect {
          delete search_reference_resource_path, headers: request_headers(format: :json), as: :json
        }.to change(SearchReference, :count).by(-1)
      end

      it 'enqueues ScoreLabelBatchWorker' do
        delete search_reference_resource_path, headers: request_headers(format: :json), as: :json

        expect(ScoreLabelBatchWorker).to have_received(:perform_async).at_least(:once)
      end
    end

    context 'with non-existant search reference' do
      let(:bogus_search_ref_id) { 666 }
      let(:bogus_search_reference_resource_path) do
        "#{search_references_collection_path.delete_suffix('.json')}/#{bogus_search_ref_id}.json"
      end

      it 'does not destroy SearchReference entry' do
        expect {
          delete bogus_search_reference_resource_path, headers: request_headers(format: :json), as: :json
        }.not_to change(SearchReference, :count)
      end

      it 'returns 404 response' do
        delete bogus_search_reference_resource_path, headers: request_headers(format: :json), as: :json

        expect(response.status).to eq 404
      end
    end
  end

  describe 'PUT #update' do
    let(:new_title) { 'new title' }

    context 'with valid params provided' do
      before do
        put search_reference_resource_path,
            params: { data: { type: search_reference, attributes: { title: new_title } } },
            headers: request_headers(format: :json),
            as: :json
      end

      it 'updates SearchReference entry' do
        expect(search_reference.reload.title).to eq new_title
      end

      it 'returns no content status' do
        expect(response.status).to eq 204
      end

      it 'returns no content' do
        expect(response.body).to be_blank
      end

      it 'enqueues ScoreLabelBatchWorker' do
        expect(ScoreLabelBatchWorker).to have_received(:perform_async).at_least(:once)
      end
    end

    context 'when the usage changes from search to fpo' do
      before do
        allow(TradeTariffBackend.search_client).to receive(:delete)
        create :search_suggestion, :search_reference, id: search_reference.id.to_s, value: search_reference.title

        put search_reference_resource_path,
            params: { data: { type: search_reference, attributes: { title: search_reference.title, usage: 'fpo' } } },
            headers: request_headers(format: :json),
            as: :json
      end

      it 'updates the usage' do
        expect(search_reference.reload.usage).to eq 'fpo'
      end

      it 'removes the search suggestion' do
        expect(SearchSuggestion.where(id: search_reference.id.to_s)).to be_empty
      end

      it 'removes the reference from the search reference index' do
        expect(TradeTariffBackend.search_client).to have_received(:delete).with(Search::SearchReferenceIndex, search_reference)
      end
    end

    context 'when the usage is not provided' do
      before do
        search_reference.update(usage: 'fpo')

        put search_reference_resource_path,
            params: { data: { type: search_reference, attributes: { title: new_title } } },
            headers: request_headers(format: :json),
            as: :json
      end

      it 'keeps the existing usage' do
        expect(search_reference.reload.usage).to eq 'fpo'
      end
    end

    context 'with invalid params provided' do
      let(:pattern) do
        { errors: Array }
      end

      before do
        put search_reference_resource_path,
            params: { data: { type: search_reference, attributes: { title: '' } } },
            headers: request_headers(format: :json),
            as: :json
      end

      it 'does not update SearchReference entry' do
        expect(search_reference.reload.title).not_to eq new_title
      end

      it 'returns not acceptable status' do
        expect(response.status).to eq 422
      end

      it 'returns record errors' do
        expect(response.body).to match_json_expression pattern
      end
    end
  end
end

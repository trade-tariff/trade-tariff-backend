RSpec.describe Api::Admin::DescriptionInterceptsController do
  routes { AdminApi.routes }

  describe '#index' do
    before do
      guided_search_intercept
      fpo_intercept
    end

    let!(:guided_search_intercept) do
      create(
        :description_intercept,
        term: 'footwear',
        sources: Sequel.pg_array(%w[guided_search], :text),
        guidance_level: 'warning',
        guidance_location: 'results',
        escalate_to_webchat: true,
        filter_prefixes: Sequel.pg_array(%w[6403 6404], :text),
      )
    end

    let!(:fpo_intercept) do
      create(
        :description_intercept,
        term: 'gift',
        sources: Sequel.pg_array(%w[fpo_search], :text),
        excluded: true,
        message: nil,
      )
    end

    it 'returns all description intercepts' do
      get :index, format: :json

      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(2)
      expect(json['data'].map { |row| row['type'] }.uniq).to eq(%w[description_intercept])
    end

    it 'includes pagination meta' do
      get :index, format: :json

      json = JSON.parse(response.body)
      expect(json.dig('meta', 'pagination')).to include(
        'page' => 1,
        'per_page' => Integer,
        'total_count' => 2,
      )
    end

    it 'filters by search term' do
      get :index, params: { q: 'foot' }, format: :json

      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(1)
      expect(json.dig('data', 0, 'attributes', 'term')).to eq('footwear')
    end

    it 'filters by source' do
      get :index, params: { source: 'fpo_search' }, format: :json

      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(1)
      expect(json.dig('data', 0, 'attributes', 'term')).to eq('gift')
    end

    it 'filters to rows with filtering enabled' do
      get :index, params: { filtering: 'true' }, format: :json

      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(1)
      expect(json.dig('data', 0, 'attributes', 'term')).to eq('footwear')
    end

    it 'filters to rows with escalation enabled' do
      get :index, params: { escalates: 'true' }, format: :json

      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(1)
      expect(json.dig('data', 0, 'attributes', 'term')).to eq('footwear')
    end

    it 'filters to rows with guidance' do
      get :index, params: { guidance: 'true' }, format: :json

      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(1)
      expect(json.dig('data', 0, 'attributes', 'term')).to eq('footwear')
    end

    it 'filters to rows that are excluded' do
      get :index, params: { excluded: 'true' }, format: :json

      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(1)
      expect(json.dig('data', 0, 'attributes', 'term')).to eq('gift')
    end
  end

  describe '#show' do
    let!(:intercept) do
      create(
        :description_intercept,
        term: 'footwear',
        guidance_level: 'warning',
        guidance_location: 'results',
        escalate_to_webchat: true,
        filter_prefixes: Sequel.pg_array(%w[6403 6404], :text),
      )
    end

    it 'returns the description intercept' do
      get :show, params: { id: intercept.id }, format: :json

      json = JSON.parse(response.body)
      expect(json).to match_json_expression(
        data: {
          id: intercept.id.to_s,
          type: 'description_intercept',
          attributes: {
            term: 'footwear',
            sources: %w[guided_search],
            message: 'Please be more specific.',
            excluded: false,
            created_at: wildcard_matcher,
            guidance_level: 'warning',
            guidance_location: 'results',
            escalate_to_webchat: true,
            filter_prefixes: %w[6403 6404],
          },
        },
        meta: {
          version: {
            current: wildcard_matcher,
            oid: wildcard_matcher,
            previous_oid: wildcard_matcher,
            has_previous_version: wildcard_matcher,
            latest_event: wildcard_matcher,
          },
        },
      )
    end

    it 'returns 404 when not found' do
      get :show, params: { id: 999_999 }, format: :json

      expect(response).to have_http_status(:not_found)
    end

    context 'when viewing a historical version' do
      before { intercept.update(message: 'Updated guidance') }

      it 'returns the historical version data' do
        version = intercept.versions.order(:id).first

        get :show, params: { id: intercept.id, filter: { oid: version.id } }, format: :json

        json = JSON.parse(response.body)
        expect(json.dig('data', 'attributes', 'message')).to eq('Please be more specific.')
        expect(json.dig('meta', 'version', 'current')).to be false
      end
    end
  end

  describe '#create' do
    it 'creates a description intercept' do
      expect {
        post :create, params: {
          data: {
            type: 'description_intercept',
            attributes: {
              term: 'bicycles',
              message: 'Read the bicycle guidance.',
              guidance_level: 'info',
              guidance_location: 'results',
              escalate_to_webchat: true,
              filter_prefixes: %w[8712 9503],
              sources: %w[guided_search fpo_search],
              excluded: false,
            },
          },
        }, format: :json
      }.to change(DescriptionIntercept, :count).by(1)

      expect(response).to have_http_status(:created)

      intercept = DescriptionIntercept.order(Sequel.desc(:id)).first
      expect(intercept.term).to eq('bicycles')
      expect(intercept.message).to eq('Read the bicycle guidance.')
      expect(intercept.guidance_level).to eq('info')
      expect(intercept.guidance_location).to eq('results')
      expect(intercept.escalate_to_webchat).to be true
      expect(intercept.filter_prefixes).to eq(%w[8712 9503])
      expect(intercept.sources).to eq(%w[guided_search fpo_search])
      expect(intercept.excluded).to be false
    end

    it 'returns validation errors for invalid attributes' do
      expect {
        post :create, params: {
          data: {
            type: 'description_intercept',
            attributes: {
              term: 'bicycles',
              excluded: true,
              filter_prefixes: %w[8712],
              sources: %w[guided_search],
              escalate_to_webchat: false,
            },
          },
        }, format: :json
      }.not_to change(DescriptionIntercept, :count)

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['errors'].first.dig('source', 'pointer')).to eq('/data/attributes/filter_prefixes')
    end
  end

  describe '#update' do
    let!(:intercept) { create(:description_intercept, term: 'footwear') }

    it 'updates the description intercept fields' do
      put :update, params: {
        id: intercept.id,
        data: {
          type: 'description_intercept',
          attributes: {
            message: 'Read the footwear guidance.',
            guidance_level: 'warning',
            guidance_location: 'results',
            escalate_to_webchat: true,
            filter_prefixes: %w[6403 6404],
            sources: %w[guided_search fpo_search],
          },
        },
      }, format: :json

      expect(response).to have_http_status(:ok)

      intercept.reload
      expect(intercept.message).to eq('Read the footwear guidance.')
      expect(intercept.guidance_level).to eq('warning')
      expect(intercept.guidance_location).to eq('results')
      expect(intercept.escalate_to_webchat).to be true
      expect(intercept.filter_prefixes).to eq(%w[6403 6404])
      expect(intercept.sources).to eq(%w[guided_search fpo_search])
    end

    it 'clears array fields when blank values are submitted' do
      intercept.update(
        filter_prefixes: Sequel.pg_array(%w[6403 6404], :text),
        sources: Sequel.pg_array(%w[guided_search fpo_search], :text),
      )

      put :update, params: {
        id: intercept.id,
        data: {
          type: 'description_intercept',
          attributes: {
            filter_prefixes: [''],
            sources: [''],
          },
        },
      }, format: :json

      expect(response).to have_http_status(:ok)

      intercept.reload
      expect(intercept.filter_prefixes).to eq([])
      expect(intercept.sources).to eq([])
    end

    it 'returns validation errors for invalid combinations' do
      put :update, params: {
        id: intercept.id,
        data: {
          type: 'description_intercept',
          attributes: {
            excluded: true,
            filter_prefixes: %w[6403],
          },
        },
      }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['errors'].first.dig('source', 'pointer')).to eq('/data/attributes/filter_prefixes')
    end
  end

  describe '#versions' do
    let!(:intercept) { create(:description_intercept, term: 'footwear') }

    before { intercept.update(message: 'Updated guidance') }

    it 'returns the intercept versions' do
      get :versions, params: { id: intercept.id }, format: :json

      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(2)
      expect(json['data'].map { |row| row['type'] }.uniq).to eq(%w[version])
    end
  end
end

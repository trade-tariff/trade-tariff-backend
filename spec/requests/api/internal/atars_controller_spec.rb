RSpec.describe Api::Internal::AtarsController do
  let(:collection_path) { '/uk/internal/atars.json' }

  describe 'GET /atars' do
    let!(:later_ruling) do
      create(
        :tariff_knowledge_public_atar_ruling,
        ref: '600000003',
        commodity_code: '630210',
        goods_nomenclature_item_id: '6302100000',
        description: 'Later cotton bed linen ruling.',
        justification: 'Classified in accordance with GIR 1.',
        keywords: Sequel.pg_array(['cotton', 'bed linen'], :text),
        validity_start_date: Date.new(2026, 1, 3),
        validity_end_date: Date.new(2029, 1, 2),
      )
    end
    let!(:earlier_ruling) do
      create(
        :tariff_knowledge_public_atar_ruling,
        ref: '600000001',
        commodity_code: '0101210000',
        goods_nomenclature_item_id: '0101210000',
        description: 'Pure-bred breeding horse.',
        justification: 'Classified in accordance with GIR 1 and heading 0101.',
        keywords: Sequel.pg_array(%w[horse], :text),
        validity_start_date: Date.new(2026, 1, 1),
        validity_end_date: Date.new(2028, 12, 31),
      )
    end

    before { create(:tariff_knowledge_public_atar_ruling, ref: '600000002') }

    it 'returns source fields in deterministic reference order with pagination metadata' do
      get collection_path, params: { page: 1, per_page: 2 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].pluck('id')).to eq(%w[600000001 600000002])
      expect(response.parsed_body.dig('meta', 'pagination')).to eq(
        'page' => 1,
        'per_page' => 2,
        'total_count' => 3,
      )

      first_record = response.parsed_body['data'].first
      expect(first_record).to include('id' => earlier_ruling.ref, 'type' => 'atar')
      expect(first_record.keys).to contain_exactly('id', 'type', 'attributes')
      expect(first_record.fetch('attributes')).to eq(
        'ref' => earlier_ruling.ref,
        'commodity_code' => '0101210000',
        'goods_nomenclature_item_id' => '0101210000',
        'description' => 'Pure-bred breeding horse.',
        'justification' => 'Classified in accordance with GIR 1 and heading 0101.',
        'keywords' => %w[horse],
        'validity_start_date' => '2026-01-01',
        'validity_end_date' => '2028-12-31',
        'source_url' => earlier_ruling.source_url,
        'fetched_at' => earlier_ruling.fetched_at.iso8601(3),
        'updated_at' => earlier_ruling.updated_at.iso8601(3),
      )
    end

    it 'returns subsequent pages without changing the deterministic ordering' do
      get collection_path, params: { page: 2, per_page: 2 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].pluck('id')).to eq(%w[600000003])
    end

    it 'filters by one or more exact comma-separated references' do
      get collection_path, params: { refs: "#{later_ruling.ref}, #{earlier_ruling.ref}" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].pluck('id')).to eq(%w[600000001 600000003])
      expect(response.parsed_body.dig('meta', 'pagination', 'total_count')).to eq(2)
    end

    it 'rejects a supplied filter without references' do
      get collection_path, params: { refs: ', ,' }

      expect(response).to have_http_status(:bad_request)
    end

    it 'rejects more references than can fit on one page' do
      get collection_path, params: { refs: Array.new(251) { |index| 600_000_000 + index }.join(',') }

      expect(response).to have_http_status(:bad_request)
    end

    it 'caps oversized pages and normalises invalid page numbers' do
      get collection_path, params: { page: -5, per_page: 10_000 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('meta', 'pagination')).to include(
        'page' => 1,
        'per_page' => 250,
      )
    end

    it 'rejects page numbers that cannot produce a safe database offset' do
      get collection_path, params: { page: "1#{'0' * 100}" }

      expect(response).to have_http_status(:bad_request)
    end

    it 'allows small pages to traverse beyond the first thousand records' do
      get collection_path, params: { page: 1_001, per_page: 1 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data']).to eq([])
    end

    it 'does not mount the endpoint for the XI service path' do
      get '/xi/internal/atars.json'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /atars/:ref' do
    it 'returns one ATAR by reference' do
      ruling = create(:tariff_knowledge_public_atar_ruling, ref: '600000004')

      get "/uk/internal/atars/#{ruling.ref}.json"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'id')).to eq(ruling.ref)
      expect(response.parsed_body.dig('data', 'attributes').keys).to contain_exactly(
        'ref',
        'commodity_code',
        'goods_nomenclature_item_id',
        'description',
        'justification',
        'keywords',
        'validity_start_date',
        'validity_end_date',
        'source_url',
        'fetched_at',
        'updated_at',
      )
    end

    it 'returns not found for an unknown reference' do
      get '/uk/internal/atars/699999999.json'

      expect(response).to have_http_status(:not_found)
    end
  end
end

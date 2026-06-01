RSpec.describe Api::Admin::GoodsNomenclatureLabels::StatsController do
  describe '#show' do
    let(:pattern) do
      {
        data: {
          id: 'stats',
          type: 'goods_nomenclature_label_stats',
          attributes: {
            total_goods_nomenclatures: Integer,
            descriptions_count: Integer,
            known_brands_count: Integer,
            colloquial_terms_count: Integer,
            synonyms_count: Integer,
            ai_created_only: Integer,
            human_edited: Integer,
            coverage_by_chapter: Array,
          },
        },
      }
    end

    it 'returns stats in JSONAPI format' do
      get '/uk/admin/goods_nomenclature_labels/stats.json', headers: request_headers(format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.body).to match_json_expression(pattern)
    end

    context 'when service returns non-zero stats' do
      let(:stats_result) do
        Api::Admin::GoodsNomenclatureLabels::StatsService::Result.new(
          total_goods_nomenclatures: 1,
          descriptions_count: 1,
          known_brands_count: 2,
          colloquial_terms_count: 0,
          synonyms_count: 1,
          ai_created_only: 1,
          human_edited: 0,
          coverage_by_chapter: [],
        )
      end

      before do
        service = instance_double(Api::Admin::GoodsNomenclatureLabels::StatsService, call: stats_result)
        allow(Api::Admin::GoodsNomenclatureLabels::StatsService).to receive(:new).and_return(service)
      end

      it 'returns correct counts' do
        get '/uk/admin/goods_nomenclature_labels/stats.json', headers: request_headers(format: :json)

        json = JSON.parse(response.body)
        attributes = json.dig('data', 'attributes')

        expect(attributes['total_goods_nomenclatures']).to eq(1)
        expect(attributes['descriptions_count']).to eq(1)
        expect(attributes['known_brands_count']).to eq(2)
        expect(attributes['colloquial_terms_count']).to eq(0)
        expect(attributes['synonyms_count']).to eq(1)
        expect(attributes['ai_created_only']).to eq(1)
        expect(attributes['human_edited']).to eq(0)
      end
    end
  end
end

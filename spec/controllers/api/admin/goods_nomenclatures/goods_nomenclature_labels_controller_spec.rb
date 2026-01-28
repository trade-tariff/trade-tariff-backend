RSpec.describe Api::Admin::GoodsNomenclatures::GoodsNomenclatureLabelsController do
  routes { AdminApi.routes }

  describe '#show' do
    let(:pattern) do
      {
        data: {
          id: String,
          type: 'goods_nomenclature_label',
          attributes: {
            goods_nomenclature_sid: Integer,
            goods_nomenclature_item_id: String,
            goods_nomenclature_type: String,
            producline_suffix: String,
            validity_start_date: String,
            validity_end_date: wildcard_matcher,
            labels: Hash,
          },
        },
        meta: {
          version: Hash,
        },
      }
    end

    context 'when goods nomenclature label is present' do
      let(:commodity) { create :commodity }

      before { create :goods_nomenclature_label, goods_nomenclature: commodity }

      it 'returns rendered record' do
        get :show, params: { goods_nomenclature_id: commodity.goods_nomenclature_item_id }, format: :json

        expect(response.body).to match_json_expression pattern
      end

      it 'returns current version meta' do
        get :show, params: { goods_nomenclature_id: commodity.goods_nomenclature_item_id }, format: :json

        json = JSON.parse(response.body)
        expect(json.dig('meta', 'version', 'current')).to be true
        expect(json.dig('meta', 'version', 'has_previous_version')).to be false
      end
    end

    context 'when goods nomenclature label is not present' do
      let(:commodity) { create :commodity }

      it 'returns not found if record was not found' do
        get :show, params: { goods_nomenclature_id: commodity.goods_nomenclature_item_id }, format: :json

        expect(response.status).to eq 404
      end
    end

    context 'when goods nomenclature does not exist' do
      it 'returns not found' do
        get :show, params: { goods_nomenclature_id: '9999999999' }, format: :json

        expect(response.status).to eq 404
      end
    end

    context 'when filtering by oid for historical version' do
      let(:commodity) { create :commodity }
      let!(:goods_nomenclature_label) { create :goods_nomenclature_label, goods_nomenclature: commodity }

      before do
        goods_nomenclature_label.set(labels: { 'description' => 'Updated description' })
        goods_nomenclature_label.save_update
        GoodsNomenclatureLabel.refresh!(concurrently: false)
      end

      it 'returns the previous version' do
        current_oid = goods_nomenclature_label.reload.oid

        get :show, params: {
          goods_nomenclature_id: commodity.goods_nomenclature_item_id,
          filter: { oid: current_oid },
        }, format: :json

        expect(response.status).to eq 200
        json = JSON.parse(response.body)
        expect(json.dig('meta', 'version', 'current')).to be false
        expect(json.dig('data', 'attributes', 'labels', 'description')).to eq 'Flibble'
      end

      it 'returns 404 when no previous version exists' do
        first_oid = GoodsNomenclatureLabel::Operation
          .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
          .order(:oid)
          .first
          .oid

        get :show, params: {
          goods_nomenclature_id: commodity.goods_nomenclature_item_id,
          filter: { oid: first_oid },
        }, format: :json

        expect(response.status).to eq 404
      end
    end
  end

  describe '#update' do
    let(:commodity) { create :commodity }

    before { create :goods_nomenclature_label, goods_nomenclature: commodity }

    context 'when save succeeded' do
      let(:new_labels) do
        {
          description: 'Updated description',
          known_brands: %w[Brand1 Brand2],
          colloquial_terms: ['common term'],
          synonyms: %w[synonym1 synonym2],
        }
      end

      it 'responds with success' do
        put :update, params: {
          goods_nomenclature_id: commodity.goods_nomenclature_item_id,
          data: { type: 'goods_nomenclature_label', attributes: { labels: new_labels } },
        }, format: :json

        expect(response.status).to eq 200
      end

      it 'inserts a new row with U operation' do
        expect {
          put :update, params: {
            goods_nomenclature_id: commodity.goods_nomenclature_item_id,
            data: { type: 'goods_nomenclature_label', attributes: { labels: new_labels } },
          }, format: :json
        }.to change {
          GoodsNomenclatureLabel::Operation
            .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
            .count
        }.by(1)
      end

      it 'creates an update operation' do
        put :update, params: {
          goods_nomenclature_id: commodity.goods_nomenclature_item_id,
          data: { type: 'goods_nomenclature_label', attributes: { labels: new_labels } },
        }, format: :json

        latest_operation = GoodsNomenclatureLabel::Operation
          .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
          .order(Sequel.desc(:oid))
          .first

        expect(latest_operation.operation).to eq 'U'
      end

      it 'returns version meta indicating previous version exists' do
        put :update, params: {
          goods_nomenclature_id: commodity.goods_nomenclature_item_id,
          data: { type: 'goods_nomenclature_label', attributes: { labels: new_labels } },
        }, format: :json

        json = JSON.parse(response.body)
        expect(json.dig('meta', 'version', 'has_previous_version')).to be true
        expect(json.dig('meta', 'version', 'previous_oid')).to be_present
      end
    end

    context 'when goods nomenclature does not exist' do
      it 'returns 404' do
        put :update, params: {
          goods_nomenclature_id: '9999999999',
          data: { type: 'goods_nomenclature_label', attributes: { labels: { description: 'test' } } },
        }, format: :json

        expect(response.status).to eq 404
      end
    end

    context 'when goods nomenclature label does not exist' do
      let(:commodity_without_label) { create :commodity }

      it 'returns 404' do
        put :update, params: {
          goods_nomenclature_id: commodity_without_label.goods_nomenclature_item_id,
          data: { type: 'goods_nomenclature_label', attributes: { labels: { description: 'test' } } },
        }, format: :json

        expect(response.status).to eq 404
      end
    end
  end
end

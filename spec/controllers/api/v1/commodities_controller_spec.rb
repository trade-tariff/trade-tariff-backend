RSpec.describe Api::V1::CommoditiesController do
  routes { V1Api.routes }

  describe 'GET #show' do
    render_views

    let!(:commodity) do
      create :commodity, :with_indent,
             :with_chapter_and_heading,
             :with_description,
             :declarable
    end

    let(:pattern) do
      {
        goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
        description: String,
        chapter: Hash,
        section: Hash,
        import_measures: Array,
        export_measures: Array,
        _response_info: Hash,
      }.ignore_extra_keys!
    end

    context 'when record is present' do
      it 'returns rendered record' do
        get :show, params: { id: commodity }, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when record is not present' do
      it 'returns not found if record was not found' do
        id = commodity.goods_nomenclature_item_id.next
        get :show, params: { id: }, format: :json

        expect(response.status).to eq 404
      end
    end

    context 'when record is hidden' do
      before { create :hidden_goods_nomenclature, goods_nomenclature_item_id: commodity.goods_nomenclature_item_id }

      it 'returns not found' do
        get :show, params: { id: commodity.goods_nomenclature_item_id }, format: :json

        expect(response.status).to eq 404
      end
    end

    context 'when commodity has children' do
      # According to Taric manual, commodities that have product line suffix of
      # 80 are not declarable. Unfortunately this is not always the case, sometimes
      # productline suffix is 80, but commodity has children and therefore should also
      # be considered to be non-declarable.
      before do
        create :goods_nomenclature, goods_nomenclature_item_id: '3903000000'
        create :commodity, :with_indent,
               indents: 3,
               goods_nomenclature_item_id: '3903909065',
               producline_suffix: '80'
      end

      let(:parent_commodity) do
        create :commodity, :with_indent,
               :with_chapter,
               indents: 2,
               goods_nomenclature_item_id: '3903909000',
               producline_suffix: '80'
      end

      it 'returns not found (is not declarable)' do
        get :show, params: { id: parent_commodity.goods_nomenclature_item_id }, format: :json

        expect(response.status).to eq 404
      end
    end
  end

  describe 'GET #changes' do
    render_views

    context 'with changes happened after chapter creation' do
      let!(:commodity) do
        create :commodity, :with_indent,
               :with_chapter_and_heading,
               :with_description,
               :declarable,
               operation_date: Time.zone.today
      end

      let(:pattern) do
        [
          {
            oid: Integer,
            model_name: 'GoodsNomenclature',
            operation: String,
            operation_date: String,
            record: {
              description: String,
              goods_nomenclature_item_id: String,
              validity_start_date: String,
              validity_end_date: nil,
            },
          },
        ].ignore_extra_values!
      end

      it 'returns commodity changes' do
        get :changes, params: { id: commodity }, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'with changes happened before requested date' do
      let!(:commodity) do
        create :commodity, :with_indent,
               :with_chapter_and_heading,
               :with_description,
               :declarable,
               operation_date: Time.zone.today
      end

      it 'does not include change records' do
        get :changes, params: { id: commodity, as_of: Time.zone.yesterday }, format: :json

        expect(response.body).to match_json_expression []
      end
    end

    context 'with changes include deleted record' do
      let!(:commodity) do
        create :commodity, :with_indent,
               :with_chapter_and_heading,
               :with_description,
               :declarable,
               operation_date: Time.zone.today
      end
      let!(:measure) do
        create :measure,
               :with_measure_type,
               goods_nomenclature: commodity,
               goods_nomenclature_sid: commodity.goods_nomenclature_sid,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               operation_date: Time.zone.today
      end

      let(:pattern) do
        [
          {
            oid: Integer,
            model_name: 'Measure',
            operation: 'D',
            record: {
              goods_nomenclature_item_id: measure.goods_nomenclature_item_id,
              measure_type: {
                description: measure.measure_type.description,
              }.ignore_extra_keys!,
            }.ignore_extra_keys!,
          }.ignore_extra_keys!,
          {
            oid: Integer,
            model_name: String,
            operation: String,
            operation_date: String,
            record: {
              description: String,
              goods_nomenclature_item_id: String,
              validity_start_date: String,
              validity_end_date: nil,
            },
          },
        ].ignore_extra_values!
      end

      before { measure.destroy }

      it 'renders record attributes' do
        get :changes, params: { id: commodity }, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end
  end
end

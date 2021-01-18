require 'rails_helper'

describe Api::V1::HeadingsController, 'GET #show' do
  render_views

  context 'non-declarable heading' do
    let(:heading) do
      create :heading, :non_grouping,
             :non_declarable,
             :with_description
    end
    let!(:chapter) do
      create :chapter,
             :with_section, :with_description,
             goods_nomenclature_item_id: heading.chapter_id
    end

    let(:pattern) do
      {
        goods_nomenclature_item_id: heading.code,
        description: String,
        commodities: Array,
        chapter: Hash,
        _response_info: Hash,
      }.ignore_extra_keys!
    end

    context 'when record is present' do
      it 'returns rendered record' do
        get :show, params: { id: heading }, format: :json
        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when record is present and commodity has hidden commodities' do
      let!(:commodity1) { create :commodity, :with_indent, :with_description, :with_chapter, :declarable, goods_nomenclature_item_id: "#{heading.short_code}010000" }
      let!(:commodity2) { create :commodity, :with_indent, :with_description, :with_chapter, :declarable, goods_nomenclature_item_id: "#{heading.short_code}020000" }

      let!(:hidden_goods_nomenclature) { create :hidden_goods_nomenclature, goods_nomenclature_item_id: commodity2.goods_nomenclature_item_id }

      it 'does not include hidden commodities in the response' do
        get :show, params: { id: heading }, format: :json

        body = JSON.parse(response.body)
        expect(
          body['commodities'].map { |c| c['goods_nomenclature_item_id'] },
        ).to include commodity1.goods_nomenclature_item_id
        expect(
          body['commodities'].map { |c| c['goods_nomenclature_item_id'] },
        ).not_to include commodity2.goods_nomenclature_item_id
      end
    end

    context 'when record is not present' do
      it 'returns not found if record was not found' do
        id = heading.goods_nomenclature_item_id.first(4).to_i + 1
        get :show, params: { id: id }, format: :json

        expect(response.status).to eq 404
      end
    end
  end

  context 'declarable heading' do
    let!(:heading) do
      create :heading, :with_indent,
             :with_description,
             :declarable
    end
    let!(:chapter) do
      create :chapter,
             :with_section, :with_description,
             goods_nomenclature_item_id: heading.chapter_id
    end

    let(:pattern) do
      {
        goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
        description: String,
        chapter: Hash,
        import_measures: Array,
        export_measures: Array,
        _response_info: Hash,
      }.ignore_extra_keys!
    end

    context 'when record is present' do
      it 'returns rendered record' do
        get :show, params: { id: heading }, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when record is not present' do
      it 'returns not found if record was not found' do
        id = heading.goods_nomenclature_item_id.first(4).to_i + 1
        get :show, params: { id: id }, format: :json

        expect(response.status).to eq 404
      end
    end

    context 'when record is hidden' do
      let!(:hidden_goods_nomenclature) { create :hidden_goods_nomenclature, goods_nomenclature_item_id: heading.goods_nomenclature_item_id }

      it 'returns not found' do
        get :show, params: { id: heading.goods_nomenclature_item_id.first(4) }, format: :json

        expect(response.status).to eq 404
      end
    end
  end
end

describe Api::V1::HeadingsController, 'GET #changes' do
  render_views

  context 'changes happened after chapter creation' do
    let(:heading) do
      create :heading, :non_grouping,
             :non_declarable,
             :with_description,
             :with_chapter,
             operation_date: Date.current
    end

    let(:pattern) do
      [
        {
          oid: Integer,
          model_name: 'Heading',
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

    it 'returns heading changes' do
      get :changes, params: { id: heading }, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end

  context 'changes happened before requested date' do
    let(:heading) do
      create :heading, :non_grouping,
             :non_declarable,
             :with_description,
             :with_chapter,
             operation_date: Date.current
    end

    it 'does not include change records' do
      get :changes, params: { id: heading, as_of: Date.yesterday }, format: :json

      expect(response.body).to match_json_expression []
    end
  end

  context 'changes include deleted record' do
    let(:heading) do
      create :heading, :non_grouping,
             :non_declarable,
             :with_description,
             :with_chapter,
             operation_date: Date.current
    end
    let!(:measure) do
      create :measure,
             :with_measure_type,
             goods_nomenclature: heading,
             goods_nomenclature_sid: heading.goods_nomenclature_sid,
             goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
             operation_date: Date.current
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
          model_name: 'Heading',
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
      get :changes, params: { id: heading }, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end
end

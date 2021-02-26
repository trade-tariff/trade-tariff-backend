require 'rails_helper'

describe Api::V2::CommoditiesController, 'GET #show' do
  let!(:commodity) do
    create :commodity, :with_indent,
           :with_chapter,
           :with_heading,
           :with_description,
           :declarable
  end
  let(:pattern) do
    {
      data: {
        id: String,
        type: 'commodity',
        attributes: Hash,
        relationships: {
          footnotes: Hash,
          section: Hash,
          chapter: Hash,
          heading: Hash,
          ancestors: Hash,
          import_measures: Hash,
          export_measures: Hash,
        },
        meta: {
          duty_calculator: Hash,
        },
      },
      included: [
        {
          id: String,
          type: 'chapter',
          attributes: Hash,
          relationships: {
            guides: Hash,
          },
        },
        {
          id: String,
          type: 'heading',
          attributes: Hash,
        },
        {
          id: String,
          type: 'section',
          attributes: Hash,
        },
      ],
    }
  end

  context 'when record is present' do
    before do
      allow(CachedCommodityService).to receive(:new).and_call_original
    end

    it 'returns rendered record' do
      get :show, params: { id: commodity }, format: :json

      expect(response.body).to match_json_expression pattern
    end

    it 'initializes the CachedCommodityService' do
      get :show, params: { id: commodity }, format: :json

      expect(CachedCommodityService).to have_received(:new).with(commodity, Time.zone.today, nil)
    end

    context 'when a filter for geographical_area_id is passed' do
      let(:filter) { { geographical_area_id: 'RO' } }

      it 'passes the filter to the CachedCommodityService' do
        get :show, params: { id: commodity, filter: filter }, format: :json

        filter_params = ActionController::Parameters.new(geographical_area_id: 'RO').permit!

        expect(CachedCommodityService).to have_received(:new).with(commodity, Time.zone.today, filter_params)
      end
    end
  end

  context 'when record is not present' do
    it 'returns not found if record was not found' do
      id = commodity.goods_nomenclature_item_id.to_i + 1
      get :show, params: { id: id }, format: :json

      expect(response.status).to eq 404
    end
  end

  context 'when record is hidden' do
    let!(:hidden_goods_nomenclature) { create :hidden_goods_nomenclature, goods_nomenclature_item_id: commodity.goods_nomenclature_item_id }

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
    let!(:heading) { create :goods_nomenclature, goods_nomenclature_item_id: '3903000000' }
    let!(:parent_commodity) do
      create :commodity, :with_indent,
             :with_chapter,
             indents: 2,
             goods_nomenclature_item_id: '3903909000',
             producline_suffix: '80'
    end
    let!(:child_commodity) do
      create :commodity, :with_indent,
             indents: 3,
             goods_nomenclature_item_id: '3903909065',
             producline_suffix: '80'
    end

    it 'returns not found (is not declarable)' do
      get :show, params: { id: parent_commodity.goods_nomenclature_item_id }, format: :json

      expect(response.status).to eq 404
    end
  end
end

describe Api::V2::CommoditiesController, 'GET #changes' do
  render_views

  context 'changes happened after chapter creation' do
    let!(:commodity) do
      create :commodity, :with_indent,
             :with_chapter,
             :with_heading,
             :with_description,
             :declarable,
             operation_date: Date.current
    end

    let(:pattern) do
      {
        data: [
          {
            id: String,
            type: 'change',
            attributes: {
              oid: Integer,
              model_name: 'GoodsNomenclature',
              operation: 'C',
              operation_date: String,
            },
            relationships: {
              record: {
                data: {
                  id: String,
                  type: 'goods_nomenclature',
                },
              },
            },
          },
        ],
        included: [
          {
            id: String,
            type: 'goods_nomenclature',
            attributes: Hash,
          },
        ],
      }
    end

    it 'returns commodity changes' do
      get :changes, params: { id: commodity }, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end

  context 'changes happened before requested date' do
    let!(:commodity) do
      create :commodity, :with_indent,
             :with_chapter,
             :with_heading,
             :with_description,
             :declarable,
             operation_date: Date.current
    end

    let!(:pattern) do
      {
        data: [],
        included: [],
      }
    end

    it 'does not include change records' do
      get :changes, params: { id: commodity, as_of: Date.yesterday }, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end

  context 'changes include deleted record' do
    let!(:commodity) do
      create :commodity, :with_indent,
             :with_chapter,
             :with_heading,
             :with_description,
             :declarable,
             operation_date: Date.current
    end
    let!(:measure) do
      create :measure,
             :with_measure_type,
             goods_nomenclature: commodity,
             goods_nomenclature_sid: commodity.goods_nomenclature_sid,
             goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
             operation_date: Date.current
    end

    let(:pattern) do
      {
        data: [
          {
            id: String,
            type: 'change',
            attributes: {
              oid: Integer,
              model_name: 'Measure',
              operation: 'C',
              operation_date: String,
            },
            relationships: {
              record: {
                data: {
                  id: String,
                  type: 'measure',
                },
              },
            },
          },
          {
            id: String,
            type: 'change',
            attributes: {
              oid: Integer,
              model_name: 'Measure',
              operation: 'D',
              operation_date: String,
            },
            relationships: {
              record: {
                data: {
                  id: String,
                  type: 'measure',
                },
              },
            },
          },
          {
            id: String,
            type: 'change',
            attributes: {
              oid: Integer,
              model_name: 'GoodsNomenclature',
              operation: 'C',
              operation_date: String,
            },
            relationships: {
              record: {
                data: {
                  id: String,
                  type: 'goods_nomenclature',
                },
              },
            },
          },
        ],
        included: [
          {
            id: String,
            type: 'measure',
            attributes: Hash,
            relationships: {
              geographical_area: {
                data: {
                  id: String,
                  type: 'geographical_area',
                },
              },
              measure_type: {
                data: {
                  id: String,
                  type: 'measure_type',
                },
              },
            },
          },
          {
            id: String,
            type: 'geographical_area',
            attributes: Hash,
          },
          {
            id: String,
            type: 'measure_type',
            attributes: Hash,
          },
          {
            id: String,
            type: 'goods_nomenclature',
            attributes: Hash,
          },
        ],
      }
    end

    before { measure.destroy }

    it 'renders record attributes' do
      get :changes, params: { id: commodity }, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end
end

RSpec.describe Api::V2::CommoditiesController do
  let(:commodity) do
    create(
      :commodity,
      :with_indent,
      :with_chapter_and_heading,
      :with_measures,
      :with_description,
      :declarable,
    )
  end

  describe 'GET #show' do
    subject(:api_response) do
      make_request
      response
    end

    let(:make_request) do
      get "/uk/api/commodities/#{commodity.code}", headers: request_headers
    end

    before do
      allow(CachedCommodityService).to receive(:new).and_call_original
    end

    it 'initializes the CachedCommodityService' do
      api_response

      expect(CachedCommodityService).to have_received(:new).with(commodity, Time.zone.today, strong_params({}))
    end

    context 'when a filter for geographical_area_id is passed' do
      subject(:api_response) do
        make_request
        response
      end

      let(:make_request) do
        get "/uk/api/commodities/#{commodity.code}", params: { filter: { geographical_area_id: 'RO' } }, headers: request_headers
      end

      before { create :geographical_area, geographical_area_id: 'RO' }

      it 'passes the filter to the CachedCommodityService' do
        api_response

        expect(CachedCommodityService).to have_received(:new).with(commodity, Time.zone.today, strong_params({ geographical_area_id: 'RO' }))
      end
    end

    context 'when a filter for meursing_additional_code_id is passed' do
      subject(:api_response) do
        make_request
        response
      end

      let(:make_request) do
        get "/uk/api/commodities/#{commodity.code}", params: { filter: { meursing_additional_code_id: '000' } }, headers: request_headers
      end

      let(:commodity) do
        create(
          :commodity,
          :with_indent,
          :with_chapter_and_heading,
          :with_description,
          :with_meursing_measures,
          :declarable,
        )
      end

      it 'passes the correct meursing additional code to the MeursingMeasureFinderService' do
        allow(MeursingMeasureFinderService).to receive(:new).and_call_original
        api_response

        expect(MeursingMeasureFinderService).to have_received(:new).with(an_instance_of(Measure), '000')
      end
    end

    context 'when fetching a commodity that does not exist' do
      subject(:api_response) do
        make_request
        response
      end

      let(:make_request) do
        get "/uk/api/commodities/#{commodity.goods_nomenclature_item_id.next}", headers: request_headers
      end

      it { is_expected.to have_http_status(:not_found) }
    end
  end

  context 'when record is hidden' do
    before do
      create(
        :hidden_goods_nomenclature,
        goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
      )

      get "/uk/api/commodities/#{commodity.goods_nomenclature_item_id}.json", headers: request_headers(format: :json)
    end

    it { expect(response).to have_http_status(:not_found) }
  end

  context 'when commodity has children' do
    before do
      create :goods_nomenclature, goods_nomenclature_item_id: '3903000000'

      create :commodity, :with_indent,
             indents: 3,
             goods_nomenclature_item_id: '3903909065',
             producline_suffix: '80'

      parent_commodity = create :commodity, :with_indent,
                                :with_chapter,
                                indents: 2,
                                goods_nomenclature_item_id: '3903909000',
                                producline_suffix: '80'

      get "/uk/api/commodities/#{parent_commodity.goods_nomenclature_item_id}.json", headers: request_headers(format: :json)
    end

    it { expect(response).to have_http_status(:not_found) }
  end

  describe 'GET /changes' do
    context 'when changes happened after chapter creation' do
      let!(:commodity) do
        create :commodity, :with_indent,
               :with_chapter_and_heading,
               :with_description,
               :declarable,
               operation_date: Time.zone.today
      end

      let(:pattern) do
        {
          data: Array,
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
        get "/uk/api/commodities/#{commodity.to_param}/changes.json", headers: request_headers(format: :json)

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when changes happened before requested date' do
      let!(:commodity) do
        create :commodity, :with_indent,
               :with_chapter_and_heading,
               :with_description,
               :declarable,
               operation_date: Time.zone.today
      end

      let!(:pattern) do
        {
          data: [],
          included: [],
        }
      end

      it 'does not include change records' do
        get "/uk/api/commodities/#{commodity.to_param}/changes.json", params: { as_of: Time.zone.yesterday }, headers: request_headers(format: :json)

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when changes include deleted record' do
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
        get "/uk/api/commodities/#{commodity.to_param}/changes.json", headers: request_headers(format: :json)

        expect(response.body).to match_json_expression pattern
      end
    end
  end
end

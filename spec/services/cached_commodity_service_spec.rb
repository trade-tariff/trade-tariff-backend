RSpec.describe CachedCommodityService do
  subject(:service) { described_class.new(commodity.reload, actual_date, filter_params) }

  let(:actual_date) { Time.zone.today }
  let(:filter_params) { ActionController::Parameters.new(geographical_area_id: 'RO').permit! }

  let!(:commodity) do
    create(
      :commodity,
      :with_chapter_and_heading,
    )
  end

  describe '#call' do
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
            import_trade_summary: Hash,
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
          {
            id: String,
            type: 'duty_expression',
            attributes: Hash,
          },
          {
            id: String,
            type: 'measure_type',
            attributes: Hash,
          },
          {
            id: String,
            type: 'legal_act',
            attributes: Hash,
          },
          {
            id: String,
            type: 'geographical_area',
            attributes: Hash,
            relationships: {
              children_geographical_areas: Hash,
            },
          },
          {
            id: String,
            type: 'measure',
            attributes: Hash,
            relationships: {
              preference_code: Hash,
              duty_expression: Hash,
              measure_type: Hash,
              legal_acts: Hash,
              measure_conditions: Hash,
              measure_condition_permutation_groups: Hash,
              measure_components: Hash,
              national_measurement_units: Hash,
              geographical_area: Hash,
              excluded_countries: Hash,
              footnotes: Hash,
              order_number: Hash,
              resolved_measure_components: Hash,
            },
            meta: { duty_calculator: { source: 'uk', scheme_code: nil } },
          },
          {
            id: String,
            type: 'measure_condition',
            attributes: Hash,
            relationships: {
              measure_condition_components: Hash,
            },
          },
          {
            id: String,
            type: 'measure_condition_component',
            attributes: Hash,
          },
          {
            id: String,
            type: 'measure_condition_permutation_group',
            attributes: Hash,
            relationships: {
              permutations: Hash,
            },
          },
          {
            id: String,
            type: 'measure_condition_permutation',
            relationships: {
              measure_conditions: Hash,
            },
          },
          {
            id: String,
            type: 'import_trade_summary',
            attributes: Hash,
          },
        ],
      }
    end

    let(:geographical_area) { create(:geographical_area, :country, :with_description, geographical_area_id: 'RO') }

    before do
      allow(Rails.cache).to receive(:fetch).and_call_original

      create :duty_expression, :with_description, duty_expression_id: '02'

      measure = create(
        :measure,
        :with_measure_conditions,
        :with_base_regulation,
        goods_nomenclature: commodity,
        goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
        goods_nomenclature_sid: commodity.goods_nomenclature_sid,
        geographical_area_id: 'RO',
        geographical_area_sid: geographical_area.geographical_area_sid,
      )
      measure.reload
    end

    it 'returns a correctly serialized hash' do
      expect(service.call.to_json).to match_json_expression pattern
    end

    context 'when the filter specifies a geographical area' do
      let(:filter_params) do
        ActionController::Parameters.new(
          geographical_area_id: geographical_area.reload.geographical_area_id,
        ).permit!
      end

      it 'does not include geographical_area_id in the cache key' do
        expected_key = "_commodity-v4-#{commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}-"
        service.call
        expect(Rails.cache).to have_received(:fetch).with(expected_key, expires_in: 24.hours)
      end
    end

    context 'when the filter does not specify a geographical area' do
      let(:filter_params) { ActionController::Parameters.new.permit! }

      it 'uses the same cache key format' do
        expected_key = "_commodity-v4-#{commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}-"
        service.call
        expect(Rails.cache).to have_received(:fetch).with(expected_key, expires_in: 24.hours)
      end
    end

    context 'when the current Thread specifies a meursing_additional_code_id' do
      include_context 'with meursing additional code id', 'foo'

      it 'includes meursing code in the cache key' do
        expected_key = "_commodity-v4-#{commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}-foo"
        service.call
        expect(Rails.cache).to have_received(:fetch).with(expected_key, expires_in: 24.hours)
      end
    end

    context 'when two requests use different geographical areas' do
      let(:other_area) { create(:geographical_area, :country, :with_description, geographical_area_id: 'DE') }

      it 'hits the same cache entry' do
        service_ro = described_class.new(commodity.reload, actual_date, ActionController::Parameters.new(geographical_area_id: 'RO').permit!)
        service_de = described_class.new(commodity.reload, actual_date, ActionController::Parameters.new(geographical_area_id: 'DE').permit!)

        service_ro.call
        service_de.call

        expected_key = "_commodity-v4-#{commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}-"
        expect(Rails.cache).to have_received(:fetch).with(expected_key, expires_in: 24.hours).twice
      end
    end
  end
end

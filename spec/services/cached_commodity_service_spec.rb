RSpec.describe CachedCommodityService do
  subject(:service) { described_class.new(commodity.reload, actual_date, filter_params) }

  let(:actual_date) { Time.zone.today }
  let(:filter_params) { ActionController::Parameters.new.permit! }

  let!(:commodity) do
    create(:commodity, :with_chapter_and_heading)
  end

  let(:serializer_options) do
    { is_collection: false, include: described_class::DEFAULT_INCLUDES }
  end

  # Build the reference response using the old code path:
  # MeasureCollection(excise + country filter) -> Presenter -> Serializer
  def reference_response(commodity, filters)
    reloaded = Commodity
      .actual
      .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
      .eager(
        ancestors: { measures: described_class::MEASURES_EAGER_LOAD_GRAPH,
                     goods_nomenclature_descriptions: {} },
        measures: described_class::MEASURES_EAGER_LOAD_GRAPH,
      )
      .take

    measures = MeasureCollection.new(reloaded.applicable_measures, filters).filter
    presenter = Api::V2::Commodities::CommodityPresenter.new(reloaded, measures)
    Api::V2::Commodities::CommoditySerializer.new(presenter, serializer_options).serializable_hash
  end

  describe '#call' do
    # MeasureType records must be created before measures because FactoryBot
    # skips the measure_type association block when measure_type_id is overridden
    before do
      create(:duty_expression, :with_description, duty_expression_id: '01')
      create(:measure_type, measure_type_id: '103', trade_movement_code: 0)
      create(:measure_type, measure_type_id: '142', trade_movement_code: 0)
    end

    let!(:ro_area) { create(:geographical_area, :country, :with_description, geographical_area_id: 'RO') }
    let!(:de_area) { create(:geographical_area, :country, :with_description, geographical_area_id: 'DE') }
    let!(:erga_omnes_area) { create(:geographical_area, :erga_omnes, :with_description) }

    let!(:erga_omnes_measure) do
      create(
        :measure,
        :with_measure_components,
        :with_base_regulation,
        measure_type_id: '103',
        goods_nomenclature: commodity,
        goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
        goods_nomenclature_sid: commodity.goods_nomenclature_sid,
        for_geo_area: erga_omnes_area,
        national: true,
        duty_amount: 4.0,
      ).tap(&:reload)
    end

    let!(:ro_measure) do
      create(
        :measure,
        :with_measure_components,
        :with_base_regulation,
        measure_type_id: '142',
        goods_nomenclature: commodity,
        goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
        goods_nomenclature_sid: commodity.goods_nomenclature_sid,
        for_geo_area: ro_area,
        duty_amount: 0.0,
      ).tap(&:reload)
    end

    let!(:de_measure) do
      create(
        :measure,
        :with_measure_components,
        :with_base_regulation,
        measure_type_id: '142',
        goods_nomenclature: commodity,
        goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
        goods_nomenclature_sid: commodity.goods_nomenclature_sid,
        for_geo_area: de_area,
        duty_amount: 2.5,
      ).tap(&:reload)
    end

    describe 'cache key' do
      before do
        allow(Rails.cache).to receive(:fetch).and_call_original
      end

      it 'does not include geographical_area_id' do
        service.call
        expected_key = "_commodity-v4-#{commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}-"
        expect(Rails.cache).to have_received(:fetch).with(expected_key, expires_in: 24.hours)
      end

      context 'with geographical_area_id filter' do
        let(:filter_params) { ActionController::Parameters.new(geographical_area_id: 'RO').permit! }

        it 'uses the same cache key regardless of country' do
          service.call
          expected_key = "_commodity-v4-#{commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}-"
          expect(Rails.cache).to have_received(:fetch).with(expected_key, expires_in: 24.hours)
        end
      end

      context 'with meursing_additional_code_id' do
        include_context 'with meursing additional code id', 'foo'

        it 'includes meursing code in cache key' do
          service.call
          expected_key = "_commodity-v4-#{commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}-foo"
          expect(Rails.cache).to have_received(:fetch).with(expected_key, expires_in: 24.hours)
        end
      end

      it 'reuses the same cache entry for different countries' do
        ro_service = described_class.new(commodity.reload, actual_date, ActionController::Parameters.new(geographical_area_id: 'RO').permit!)
        de_service = described_class.new(commodity.reload, actual_date, ActionController::Parameters.new(geographical_area_id: 'DE').permit!)

        ro_service.call
        de_service.call

        expected_key = "_commodity-v4-#{commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}-"
        expect(Rails.cache).to have_received(:fetch).with(expected_key, expires_in: 24.hours).twice
      end
    end

    describe 'measure filtering' do
      context 'without geographical_area_id filter' do
        it 'returns all measures' do
          result = service.call
          import_sids = result[:data][:relationships][:import_measures][:data].map { |r| r[:id].to_i }

          expect(import_sids).to include(
            erga_omnes_measure.measure_sid,
            ro_measure.measure_sid,
            de_measure.measure_sid,
          )
        end
      end

      context 'with geographical_area_id filter for RO' do
        let(:filter_params) { ActionController::Parameters.new(geographical_area_id: 'RO').permit! }

        it 'keeps erga omnes measure and RO-specific measure' do
          result = service.call
          import_sids = result[:data][:relationships][:import_measures][:data].map { |r| r[:id].to_i }

          expect(import_sids).to include(erga_omnes_measure.measure_sid, ro_measure.measure_sid)
          expect(import_sids).not_to include(de_measure.measure_sid)
        end

        it 'removes DE measure from included array' do
          result = service.call
          included_measure_sids = result[:included]
            .select { |e| e[:type] == :measure }
            .map { |e| e[:id].to_i }

          expect(included_measure_sids).to include(erga_omnes_measure.measure_sid)
          expect(included_measure_sids).to include(ro_measure.measure_sid)
          expect(included_measure_sids).not_to include(de_measure.measure_sid)
        end
      end

      context 'with geographical_area_id filter for DE' do
        let(:filter_params) { ActionController::Parameters.new(geographical_area_id: 'DE').permit! }

        it 'keeps erga omnes measure and DE-specific measure' do
          result = service.call
          import_sids = result[:data][:relationships][:import_measures][:data].map { |r| r[:id].to_i }

          expect(import_sids).to include(erga_omnes_measure.measure_sid, de_measure.measure_sid)
          expect(import_sids).not_to include(ro_measure.measure_sid)
        end
      end
    end

    describe 'derived value recomputation' do
      context 'with geographical_area_id filter' do
        let(:filter_params) { ActionController::Parameters.new(geographical_area_id: 'RO').permit! }

        it 'recomputes basic_duty_rate from surviving third-country measures' do
          result = service.call
          ref = reference_response(commodity, filter_params.to_h.symbolize_keys)

          expect(result[:data][:attributes][:basic_duty_rate]).to eq(ref[:data][:attributes][:basic_duty_rate])
        end

        it 'recomputes meursing_code from surviving measures' do
          result = service.call
          ref = reference_response(commodity, filter_params.to_h.symbolize_keys)

          expect(result[:data][:attributes][:meursing_code]).to eq(ref[:data][:attributes][:meursing_code])
        end

        it 'recomputes zero_mfn_duty from surviving third-country measures' do
          result = service.call
          ref = reference_response(commodity, filter_params.to_h.symbolize_keys)

          expect(result[:data][:meta][:duty_calculator][:zero_mfn_duty]).to eq(ref[:data][:meta][:duty_calculator][:zero_mfn_duty])
        end

        it 'recomputes trade_defence from surviving measures' do
          result = service.call
          ref = reference_response(commodity, filter_params.to_h.symbolize_keys)

          expect(result[:data][:meta][:duty_calculator][:trade_defence]).to eq(ref[:data][:meta][:duty_calculator][:trade_defence])
        end

        it 'recomputes applicable_additional_codes from surviving measures' do
          result = service.call
          ref = reference_response(commodity, filter_params.to_h.symbolize_keys)

          expect(result[:data][:meta][:duty_calculator][:applicable_additional_codes]).to eq(ref[:data][:meta][:duty_calculator][:applicable_additional_codes])
        end

        it 'recomputes applicable_measure_units from surviving measures' do
          result = service.call
          ref = reference_response(commodity, filter_params.to_h.symbolize_keys)

          expect(result[:data][:meta][:duty_calculator][:applicable_measure_units]).to eq(ref[:data][:meta][:duty_calculator][:applicable_measure_units])
        end

        it 'recomputes applicable_vat_options from surviving measures' do
          result = service.call
          ref = reference_response(commodity, filter_params.to_h.symbolize_keys)

          expect(result[:data][:meta][:duty_calculator][:applicable_vat_options]).to eq(ref[:data][:meta][:duty_calculator][:applicable_vat_options])
        end
      end
    end

    describe 'import_trade_summary recomputation' do
      context 'with geographical_area_id filter' do
        let(:filter_params) { ActionController::Parameters.new(geographical_area_id: 'RO').permit! }

        it 'recomputes import_trade_summary attributes to match reference' do
          result = service.call
          ref = reference_response(commodity, filter_params.to_h.symbolize_keys)

          result_summary = result[:included].find { |e| e[:type] == :import_trade_summary }
          ref_summary = ref[:included].find { |e| e[:type].to_s == 'import_trade_summary' }

          expect(result_summary[:attributes][:basic_third_country_duty]).to eq(ref_summary[:attributes][:basic_third_country_duty])
          expect(result_summary[:attributes][:preferential_tariff_duty]).to eq(ref_summary[:attributes][:preferential_tariff_duty])
          expect(result_summary[:attributes][:preferential_quota_duty]).to eq(ref_summary[:attributes][:preferential_quota_duty])
        end
      end
    end

    describe 'included array cleanup' do
      context 'with geographical_area_id filter' do
        let(:filter_params) { ActionController::Parameters.new(geographical_area_id: 'RO').permit! }

        it 'removes orphaned measure-related entries for filtered-out measures' do
          result = service.call

          duty_expr_ids = result[:included]
            .select { |e| e[:type] == :duty_expression }
            .map { |e| e[:id] }

          expect(duty_expr_ids).to include("#{erga_omnes_measure.measure_sid}-duty_expression")
          expect(duty_expr_ids).to include("#{ro_measure.measure_sid}-duty_expression")
          expect(duty_expr_ids).not_to include("#{de_measure.measure_sid}-duty_expression")
        end

        it 'preserves shared non-measure entries' do
          result = service.call
          types = result[:included].map { |e| e[:type].to_s }

          expect(types).to include('chapter', 'heading', 'section')
        end

        it 'does not leak orphaned included entries from filtered-out measures' do
          result = service.call
          ref = reference_response(commodity, filter_params.to_h.symbolize_keys)

          result_entries = result[:included].map { |e| [e[:type].to_s, e[:id].to_s] }.sort
          ref_entries = ref[:included].map { |e| [e[:type].to_s, e[:id].to_s] }.sort

          expect(result_entries).to eq(ref_entries)
        end
      end
    end

    describe 'full response equivalence' do
      shared_examples 'matches reference response' do |country_id|
        it "produces identical measure sids for #{country_id || 'no filter'}" do
          result = service.call
          ref = reference_response(commodity, filter_params.to_h.symbolize_keys)

          result_sids = result[:data][:relationships][:import_measures][:data].map { |r| r[:id].to_s }.sort
          ref_sids = ref[:data][:relationships][:import_measures][:data].map { |r| r[:id].to_s }.sort

          expect(result_sids).to eq(ref_sids)
        end

        it "produces identical duty_calculator meta for #{country_id || 'no filter'}" do
          result = service.call
          ref = reference_response(commodity, filter_params.to_h.symbolize_keys)

          expect(result[:data][:meta][:duty_calculator]).to eq(ref[:data][:meta][:duty_calculator])
        end

        it "produces identical import_trade_summary for #{country_id || 'no filter'}" do
          result = service.call
          ref = reference_response(commodity, filter_params.to_h.symbolize_keys)

          result_summary = result[:included].find { |e| e[:type] == :import_trade_summary }
          ref_summary = ref[:included].find { |e| e[:type].to_s == 'import_trade_summary' }

          expect(result_summary[:attributes]).to eq(ref_summary[:attributes])
        end

        it "produces identical basic_duty_rate for #{country_id || 'no filter'}" do
          result = service.call
          ref = reference_response(commodity, filter_params.to_h.symbolize_keys)

          expect(result[:data][:attributes][:basic_duty_rate]).to eq(ref[:data][:attributes][:basic_duty_rate])
        end

        it "includes only reachable entries (no orphans from other countries) for #{country_id || 'no filter'}" do
          result = service.call
          ref = reference_response(commodity, filter_params.to_h.symbolize_keys)

          result_entries = result[:included].map { |e| [e[:type].to_s, e[:id].to_s] }.sort
          ref_entries = ref[:included].map { |e| [e[:type].to_s, e[:id].to_s] }.sort

          expect(result_entries).to eq(ref_entries)
        end
      end

      context 'without filter' do
        let(:filter_params) { ActionController::Parameters.new.permit! }

        include_examples 'matches reference response', nil
      end

      context 'with RO filter' do
        let(:filter_params) { ActionController::Parameters.new(geographical_area_id: 'RO').permit! }

        include_examples 'matches reference response', 'RO'
      end

      context 'with DE filter' do
        let(:filter_params) { ActionController::Parameters.new(geographical_area_id: 'DE').permit! }

        include_examples 'matches reference response', 'DE'
      end
    end
  end
end

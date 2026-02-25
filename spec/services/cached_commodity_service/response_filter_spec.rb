RSpec.describe CachedCommodityService::ResponseFilter do
  describe '#call' do
    let(:measure_sid) { 12_345 }
    let(:other_measure_sid) { 12_346 }

    let(:base_hash) do
      {
        data: {
          id: '1',
          type: :commodity,
          attributes: {
            basic_duty_rate: '4.00%',
            meursing_code: false,
          },
          relationships: {
            chapter: { data: { id: '1', type: :chapter } },
            import_measures: { data: [
              { id: measure_sid, type: :measure },
              { id: other_measure_sid, type: :measure },
            ] },
            export_measures: { data: [] },
            import_trade_summary: { data: { id: 'abc123', type: :import_trade_summary } },
          },
          meta: {
            duty_calculator: {
              applicable_additional_codes: {},
              applicable_measure_units: {},
              applicable_vat_options: {},
              entry_price_system: false,
              meursing_code: false,
              source: 'uk',
              trade_defence: false,
              zero_mfn_duty: false,
            },
          },
        },
        included: [
          { id: '1', type: :chapter, attributes: { description: 'Chapter 1' } },
          { id: measure_sid,
            type: :measure,
            attributes: { import: true },
            relationships: {
              preference_code: { data: nil },
              duty_expression: { data: { id: "#{measure_sid}-duty_expression", type: :duty_expression } },
              measure_type: { data: { id: '103', type: :measure_type } },
              legal_acts: { data: [] },
              measure_conditions: { data: [] },
              measure_condition_permutation_groups: { data: [] },
              measure_components: { data: [] },
              national_measurement_units: { data: [] },
              geographical_area: { data: { id: 'RO', type: :geographical_area } },
              excluded_countries: { data: [] },
              footnotes: { data: [] },
              order_number: { data: nil },
              resolved_measure_components: { data: [] },
            } },
          { id: other_measure_sid,
            type: :measure,
            attributes: { import: true },
            relationships: {
              preference_code: { data: nil },
              duty_expression: { data: { id: "#{other_measure_sid}-duty_expression", type: :duty_expression } },
              measure_type: { data: { id: '103', type: :measure_type } },
              legal_acts: { data: [] },
              measure_conditions: { data: [] },
              measure_condition_permutation_groups: { data: [] },
              measure_components: { data: [] },
              national_measurement_units: { data: [] },
              geographical_area: { data: { id: 'DE', type: :geographical_area } },
              excluded_countries: { data: [] },
              footnotes: { data: [] },
              order_number: { data: nil },
              resolved_measure_components: { data: [] },
            } },
          { id: "#{measure_sid}-duty_expression", type: :duty_expression, attributes: {} },
          { id: "#{other_measure_sid}-duty_expression", type: :duty_expression, attributes: {} },
          { id: '103', type: :measure_type, attributes: {} },
          { id: 'RO', type: :geographical_area, attributes: {} },
          { id: 'DE', type: :geographical_area, attributes: {} },
          { id: 'abc123',
            type: :import_trade_summary,
            attributes: {
              basic_third_country_duty: nil,
              preferential_tariff_duty: nil,
              preferential_quota_duty: nil,
            } },
        ],
      }
    end

    let(:measure_meta) do
      {
        measure_sid => {
          geographical_area_id: 'RO',
          erga_omnes: false,
          national: false,
          meursing_type: false,
          excluded_geographical_area_ids: [],
          contained_geographical_area_ids: [],
          import: true,
          export: false,
          third_country: false,
          zero_mfn: false,
          formatted_duty_expression: '4.00%',
          trade_remedy: false,
          entry_price_system: false,
          meursing: false,
          vat: false,
          expresses_unit: false,
          tariff_preference: false,
          preferential_quota: false,
          measure_type_id: '103',
          authorised_use: false,
          special_nature: false,
          authorised_use_provisions_submission: false,
          gsp_or_dcts: false,
          additional_code_contribution: nil,
          has_no_additional_code: true,
          measure_unit_contributions: nil,
          vat_option_contribution: nil,
        },
        other_measure_sid => {
          geographical_area_id: 'DE',
          erga_omnes: false,
          national: false,
          meursing_type: false,
          excluded_geographical_area_ids: [],
          contained_geographical_area_ids: [],
          import: true,
          export: false,
          third_country: false,
          zero_mfn: false,
          formatted_duty_expression: '2.50%',
          trade_remedy: false,
          entry_price_system: false,
          meursing: false,
          vat: false,
          expresses_unit: false,
          tariff_preference: false,
          preferential_quota: false,
          measure_type_id: '103',
          authorised_use: false,
          special_nature: false,
          authorised_use_provisions_submission: false,
          gsp_or_dcts: false,
          additional_code_contribution: nil,
          has_no_additional_code: true,
          measure_unit_contributions: nil,
          vat_option_contribution: nil,
        },
      }
    end

    let(:cached_data) { { v: 4, hash: base_hash, measure_meta: measure_meta } }

    context 'without geographical_area_id filter' do
      subject(:filter) { described_class.new(cached_data, nil) }

      it 'returns the cached hash unchanged' do
        result = filter.call
        expect(result[:data][:relationships][:import_measures][:data].size).to eq(2)
      end
    end

    context 'with geographical_area_id filter' do
      subject(:filter) { described_class.new(cached_data, 'RO') }

      it 'keeps only measures relevant for that country' do
        result = filter.call
        surviving_ids = result[:data][:relationships][:import_measures][:data].map { |r| r[:id] }
        expect(surviving_ids).to eq([measure_sid])
      end

      it 'removes the non-matching measure from included' do
        result = filter.call
        measure_entries = result[:included].select { |e| e[:type] == :measure }
        expect(measure_entries.size).to eq(1)
        expect(measure_entries.first[:id]).to eq(measure_sid)
      end

      it 'removes orphaned duty_expression entries' do
        result = filter.call
        duty_expressions = result[:included].select { |e| e[:type] == :duty_expression }
        expect(duty_expressions.size).to eq(1)
        expect(duty_expressions.first[:id]).to eq("#{measure_sid}-duty_expression")
      end

      it 'preserves non-measure-related included entries' do
        result = filter.call
        chapter_entries = result[:included].select { |e| e[:type] == :chapter }
        expect(chapter_entries.size).to eq(1)
      end

      it 'recomputes import_trade_summary' do
        result = filter.call
        trade_summary = result[:included].find { |e| e[:type] == :import_trade_summary }
        expect(trade_summary).to be_present
      end
    end

    context 'with erga omnes measure' do
      subject(:filter) { described_class.new(cached_data, 'RO') }

      let(:measure_meta) do
        {
          measure_sid => {
            geographical_area_id: '1011',
            erga_omnes: true,
            national: true,
            meursing_type: false,
            excluded_geographical_area_ids: [],
            contained_geographical_area_ids: [],
            import: true,
            export: false,
            third_country: true,
            zero_mfn: false,
            formatted_duty_expression: '4.00%',
            trade_remedy: false,
            entry_price_system: false,
            meursing: false,
            vat: false,
            expresses_unit: false,
            tariff_preference: false,
            preferential_quota: false,
            measure_type_id: '103',
            authorised_use: false,
            special_nature: false,
            authorised_use_provisions_submission: false,
            gsp_or_dcts: false,
            additional_code_contribution: nil,
            has_no_additional_code: true,
            measure_unit_contributions: nil,
            vat_option_contribution: nil,
          },
        }
      end

      it 'keeps erga omnes + national measures for any country' do
        result = filter.call
        surviving_ids = result[:data][:relationships][:import_measures][:data].map { |r| r[:id] }
        expect(surviving_ids).to include(measure_sid)
      end
    end

    context 'with excluded country' do
      subject(:filter) { described_class.new(cached_data, 'RO') }

      let(:measure_meta) do
        {
          measure_sid => {
            geographical_area_id: '1011',
            erga_omnes: true,
            national: true,
            meursing_type: false,
            excluded_geographical_area_ids: %w[RO],
            contained_geographical_area_ids: [],
            import: true,
            export: false,
            third_country: true,
            zero_mfn: false,
            formatted_duty_expression: '4.00%',
            trade_remedy: false,
            entry_price_system: false,
            meursing: false,
            vat: false,
            expresses_unit: false,
            tariff_preference: false,
            preferential_quota: false,
            measure_type_id: '103',
            authorised_use: false,
            special_nature: false,
            authorised_use_provisions_submission: false,
            gsp_or_dcts: false,
            additional_code_contribution: nil,
            has_no_additional_code: true,
            measure_unit_contributions: nil,
            vat_option_contribution: nil,
          },
        }
      end

      it 'excludes measures where the country is in excluded list' do
        result = filter.call
        surviving_ids = result[:data][:relationships][:import_measures][:data].map { |r| r[:id] }
        expect(surviving_ids).not_to include(measure_sid)
      end
    end

    context 'when recomputing basic_duty_rate' do
      subject(:filter) { described_class.new(cached_data, 'RO') }

      let(:measure_meta) do
        {
          measure_sid => {
            geographical_area_id: 'RO',
            erga_omnes: false,
            national: false,
            meursing_type: false,
            excluded_geographical_area_ids: [],
            contained_geographical_area_ids: [],
            import: true,
            export: false,
            third_country: true,
            zero_mfn: false,
            formatted_duty_expression: '8.00%',
            trade_remedy: false,
            entry_price_system: false,
            meursing: false,
            vat: false,
            expresses_unit: false,
            tariff_preference: false,
            preferential_quota: false,
            measure_type_id: '103',
            authorised_use: false,
            special_nature: false,
            authorised_use_provisions_submission: false,
            gsp_or_dcts: false,
            additional_code_contribution: nil,
            has_no_additional_code: true,
            measure_unit_contributions: nil,
            vat_option_contribution: nil,
          },
        }
      end

      it 'sets basic_duty_rate from the single third_country measure' do
        result = filter.call
        expect(result[:data][:attributes][:basic_duty_rate]).to eq('8.00%')
      end
    end

    context 'when filtering does not mutate the original cached data' do
      subject(:filter) { described_class.new(cached_data, 'RO') }

      it 'preserves the original hash' do
        original_count = cached_data[:hash][:data][:relationships][:import_measures][:data].size
        filter.call
        expect(cached_data[:hash][:data][:relationships][:import_measures][:data].size).to eq(original_count)
      end
    end
  end
end

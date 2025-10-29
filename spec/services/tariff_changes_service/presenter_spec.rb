RSpec.describe TariffChangesService::Presenter do
  let(:test_class) do
    Class.new do
      include TariffChangesService::Presenter
    end
  end
  let(:instance) { test_class.new }

  describe '#commodity_description' do
    let(:goods_nomenclature) { create(:commodity, :declarable, validity_start_date: Date.new(2024, 1, 1)) }
    let(:goods_nomenclature_description) { instance_double(GoodsNomenclatureDescription, csv_formatted_description: 'Live horses, asses, mules and hinnies') }

    before do
      allow(TimeMachine).to receive(:at).and_yield
      allow(goods_nomenclature).to receive(:goods_nomenclature_description).and_return(goods_nomenclature_description)
    end

    it 'returns the CSV formatted description' do
      result = instance.commodity_description(goods_nomenclature)
      expect(result).to eq('Live horses, asses, mules and hinnies')
    end

    it 'calls TimeMachine with the commodity validity_start_date' do
      instance.commodity_description(goods_nomenclature)
      expect(TimeMachine).to have_received(:at).with(goods_nomenclature.validity_start_date)
    end

    context 'when goods_nomenclature_description is not available' do
      before do
        allow(goods_nomenclature).to receive(:goods_nomenclature_description).and_return(nil)
      end

      it 'raises an error when trying to call csv_formatted_description on nil' do
        expect { instance.commodity_description(goods_nomenclature) }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#measure_type' do
    context 'when measure is blank' do
      it 'returns N/A' do
        result = instance.measure_type(nil)
        expect(result).to eq('N/A')
      end

      it 'returns N/A for empty string' do
        result = instance.measure_type('')
        expect(result).to eq('N/A')
      end
    end

    context 'when measure is present' do
      let(:measure_type) { create(:measure_type) }
      let(:measure) { create(:measure, measure_type: measure_type) }

      before do
        allow(measure_type).to receive(:description).and_return('Third country duty')
      end

      it 'returns the measure type description' do
        result = instance.measure_type(measure)
        expect(result).to eq('Third country duty')
      end
    end

    context 'when measure type has no description' do
      let(:measure_type) { create(:measure_type) }
      let(:measure) { create(:measure, measure_type: measure_type) }

      before do
        allow(measure.measure_type).to receive(:description).and_return(nil)
      end

      it 'returns nil' do
        result = instance.measure_type(measure)
        expect(result).to be_nil
      end
    end
  end

  describe '#import_export' do
    context 'when measure is blank' do
      it 'returns N/A for nil' do
        result = instance.import_export(nil)
        expect(result).to eq('N/A')
      end

      it 'returns N/A for empty string' do
        result = instance.import_export('')
        expect(result).to eq('N/A')
      end
    end

    context 'when measure has trade_movement_code 0 (Import)' do
      let(:measure_type) { create(:measure_type, trade_movement_code: 0) }
      let(:measure) { create(:measure, measure_type: measure_type) }

      it 'returns Import' do
        result = instance.import_export(measure)
        expect(result).to eq('Import')
      end
    end

    context 'when measure has trade_movement_code 1 (Export)' do
      let(:measure_type) { create(:measure_type, trade_movement_code: 1) }
      let(:measure) { create(:measure, measure_type: measure_type) }

      it 'returns Export' do
        result = instance.import_export(measure)
        expect(result).to eq('Export')
      end
    end

    context 'when measure has trade_movement_code 2 (Both)' do
      let(:measure_type) { create(:measure_type, trade_movement_code: 2) }
      let(:measure) { create(:measure, measure_type: measure_type) }

      it 'returns Both' do
        result = instance.import_export(measure)
        expect(result).to eq('Both')
      end
    end

    context 'when measure has unknown trade_movement_code' do
      let(:measure_type) { create(:measure_type, trade_movement_code: 99) }
      let(:measure) { create(:measure, measure_type: measure_type) }

      it 'returns empty string' do
        result = instance.import_export(measure)
        expect(result).to eq('')
      end
    end

    context 'when measure_type is nil' do
      let(:measure) { create(:measure, measure_type: nil) }

      it 'returns empty string' do
        result = instance.import_export(measure)
        expect(result).to eq('')
      end
    end

    context 'when trade_movement_code is nil' do
      let(:measure_type) { create(:measure_type, trade_movement_code: nil) }
      let(:measure) { create(:measure, measure_type: measure_type) }

      it 'returns empty string' do
        result = instance.import_export(measure)
        expect(result).to eq('')
      end
    end
  end

  describe '#geo_area' do
    context 'when geo_area is blank' do
      it 'returns N/A for nil' do
        result = instance.geo_area(nil)
        expect(result).to eq('N/A')
      end

      it 'returns N/A for empty string' do
        result = instance.geo_area('')
        expect(result).to eq('N/A')
      end
    end

    context 'when geo_area is present' do
      let(:geo_area) { create(:geographical_area, :with_description, geographical_area_id: 'FR') }

      before do
        allow(geo_area.geographical_area_description).to receive(:description).and_return('France')
      end

      it 'returns formatted geo area with description and id' do
        result = instance.geo_area(geo_area)
        expect(result).to eq('France (FR)')
      end

      context 'when geo_area is erga_omnes' do
        let(:geo_area) { create(:geographical_area, :erga_omnes, :with_description) }

        before do
          allow(geo_area).to receive(:erga_omnes?).and_return(true)
        end

        it 'returns All countries with the id' do
          result = instance.geo_area(geo_area)
          expect(result).to eq("All countries (#{geo_area.id})")
        end
      end

      context 'when excluded_geographical_areas are provided' do
        let(:excluded_area_1) { create(:geographical_area, :with_description, geographical_area_id: 'DE') }
        let(:excluded_area_2) { create(:geographical_area, :with_description, geographical_area_id: 'IT') }
        let(:excluded_geographical_areas) { [excluded_area_1, excluded_area_2] }

        before do
          allow(excluded_area_1.geographical_area_description).to receive(:description).and_return('Germany')
          allow(excluded_area_2.geographical_area_description).to receive(:description).and_return('Italy')
        end

        it 'includes excluded areas in the result' do
          result = instance.geo_area(geo_area, excluded_geographical_areas)
          expect(result).to eq('France (FR) excluding Germany, Italy')
        end
      end

      context 'when excluded_geographical_areas is empty' do
        let(:excluded_geographical_areas) { [] }

        it 'does not include excluding clause' do
          result = instance.geo_area(geo_area, excluded_geographical_areas)
          expect(result).to eq('France (FR)')
        end
      end
    end

    context 'with complex scenario: erga_omnes with exclusions' do
      let(:geo_area) { create(:geographical_area, :erga_omnes, :with_description) }
      let(:excluded_area) { create(:geographical_area, :with_description, geographical_area_id: 'US') }
      let(:excluded_geographical_areas) { [excluded_area] }

      before do
        allow(geo_area).to receive(:erga_omnes?).and_return(true)
        allow(excluded_area.geographical_area_description).to receive(:description).and_return('United States')
      end

      it 'returns All countries with exclusions' do
        result = instance.geo_area(geo_area, excluded_geographical_areas)
        expect(result).to eq("All countries (#{geo_area.id}) excluding United States")
      end
    end
  end

  describe 'integration test with real objects' do
    it 'can be included in other classes and used' do
      test_service = Class.new do
        include TariffChangesService::Presenter

        def format_data(commodity, measure, geo_area)
          {
            description: commodity_description(commodity),
            measure_type: measure_type(measure),
            import_export: import_export(measure),
            geo_area: geo_area(geo_area),
          }
        end
      end

      service = test_service.new
      commodity = create(:commodity, :declarable, validity_start_date: Date.new(2024, 1, 1))
      measure_type = create(:measure_type, trade_movement_code: 0)
      measure = create(:measure, measure_type: measure_type)
      geo_area = create(:geographical_area, :with_description, geographical_area_id: 'GB')

      goods_nomenclature_description = instance_double(GoodsNomenclatureDescription, csv_formatted_description: 'Test product')
      allow(TimeMachine).to receive(:at).and_yield
      allow(commodity).to receive(:goods_nomenclature_description).and_return(goods_nomenclature_description)
      allow(geo_area.geographical_area_description).to receive(:description).and_return('United Kingdom')
      allow(measure_type).to receive(:description).and_return('Standard rate')

      result = service.format_data(commodity, measure, geo_area)

      expect(result).to eq({
        description: 'Test product',
        measure_type: 'Standard rate',
        import_export: 'Import',
        geo_area: 'United Kingdom (GB)',
      })
    end
  end
end

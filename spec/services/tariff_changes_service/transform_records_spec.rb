RSpec.describe TariffChangesService::TransformRecords do
  subject(:service) { described_class.new(operation_date) }

  let(:operation_date) { Date.parse('2024-08-12') }

  describe '.call' do
    it 'creates an instance and calls #call' do
      instance = described_class.new(operation_date)
      allow(described_class).to receive(:new).with(operation_date).and_return(instance)
      allow(instance).to receive(:call).and_return([])

      result = described_class.call(operation_date)

      expect(described_class).to have_received(:new).with(operation_date)
      expect(instance).to have_received(:call)
      expect(result).to eq([])
    end
  end

  describe '#initialize' do
    it 'sets the operation_date' do
      expect(service.operation_date).to eq(operation_date)
    end

    it 'converts string date to Date object' do
      string_service = described_class.new('2024-08-12')
      expect(string_service.operation_date).to eq(Date.parse('2024-08-12'))
    end
  end

  describe '#call' do
    context 'when no tariff changes exist for the date' do
      it 'returns an empty array' do
        expect(service.call).to eq([])
      end
    end

    context 'when tariff changes exist' do
      let(:goods_nomenclature) do
        create(:goods_nomenclature,
               goods_nomenclature_item_id: '0101010100',
               validity_start_date: 1.day.ago)
      end
      let(:goods_nomenclature_description) do
        create(:goods_nomenclature_description,
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               description: 'Live horses')
      end
      let(:tariff_change) do
        create(:tariff_change,
               operation_date: operation_date,
               date_of_effect: Date.parse('2024-08-15'),
               type: 'Commodity',
               action: 'creation',
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
      end

      before do
        goods_nomenclature
        goods_nomenclature_description
        tariff_change

        # Mock TimeMachine for commodity description
        allow(TimeMachine).to receive(:at).and_yield
        allow(goods_nomenclature).to receive(:goods_nomenclature_description).and_return(goods_nomenclature_description)
        allow(goods_nomenclature_description).to receive(:csv_formatted_description).and_return('Live horses')
      end

      it 'returns transformed records' do
        result = service.call

        expect(result).to be_an(Array)
        expect(result.size).to eq(1)

        record = result.first
        expect(record).to include(
          commodity_code: '0101010100',
          chapter: '01',
          type_of_change: 'Commodity Added',
          date_of_effect: '2024-08-15',
          import_export: 'N/A',
          geo_area: 'N/A',
          measure_type: 'N/A',
          commodity_code_description: 'Live horses',
        )
      end

      it 'includes all required fields' do
        result = service.call
        record = result.first

        expected_keys = %i[
          import_export
          geo_area
          measure_type
          chapter
          commodity_code
          commodity_code_description
          type_of_change
          change
          date_of_effect
          ott_url
          api_url
        ]

        expect(record.keys).to match_array(expected_keys)
      end

      it 'builds correct URLs' do
        result = service.call
        record = result.first

        expected_ott_url = 'https://www.trade-tariff.service.gov.uk/commodities/0101010100?day=15&month=8&year=2024'
        expected_api_url = 'https://www.trade-tariff.service.gov.uk/uk/api/commodities/0101010100'

        expect(record[:ott_url]).to eq(expected_ott_url)
        expect(record[:api_url]).to eq(expected_api_url)
      end
    end
  end

  describe 'presenter methods' do
    describe '#commodity_description' do
      let(:goods_nomenclature) do
        create(:goods_nomenclature, validity_start_date: 1.day.ago)
      end
      let(:goods_nomenclature_description) do
        create(:goods_nomenclature_description,
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               description: 'Test description')
      end

      before do
        goods_nomenclature_description
        allow(TimeMachine).to receive(:at).and_yield
        allow(goods_nomenclature).to receive(:goods_nomenclature_description).and_return(goods_nomenclature_description)
        allow(goods_nomenclature_description).to receive(:csv_formatted_description).and_return('Test description')
      end

      it 'returns the formatted description' do
        result = service.send(:commodity_description, goods_nomenclature)
        expect(result).to eq('Test description')
      end

      it 'calls TimeMachine with validity_start_date' do
        service.send(:commodity_description, goods_nomenclature)
        expect(TimeMachine).to have_received(:at).with(goods_nomenclature.validity_start_date)
      end
    end

    describe '#measure_type' do
      context 'when measure is blank' do
        it 'returns N/A' do
          result = service.send(:measure_type, nil)
          expect(result).to eq('N/A')
        end
      end

      context 'when measure is present' do
        let(:measure_type) { create(:measure_type) }
        let(:measure) { create(:measure, measure_type: measure_type) }

        before do
          # Stub the description delegation to work around factory association issues
          allow(measure_type).to receive(:description).and_return('Third country duty')
        end

        it 'returns the measure type description' do
          result = service.send(:measure_type, measure)
          expect(result).to eq('Third country duty')
        end
      end
    end

    describe '#import_export' do
      context 'when measure is blank' do
        it 'returns N/A' do
          result = service.send(:import_export, nil)
          expect(result).to eq('N/A')
        end
      end

      context 'when measure has trade_movement_code 0' do
        let(:measure_type) { create(:measure_type, trade_movement_code: 0) }
        let(:measure) { create(:measure, measure_type: measure_type) }

        it 'returns Import' do
          result = service.send(:import_export, measure)
          expect(result).to eq('Import')
        end
      end

      context 'when measure has trade_movement_code 1' do
        let(:measure_type) { create(:measure_type, trade_movement_code: 1) }
        let(:measure) { create(:measure, measure_type: measure_type) }

        it 'returns Export' do
          result = service.send(:import_export, measure)
          expect(result).to eq('Export')
        end
      end

      context 'when measure has trade_movement_code 2' do
        let(:measure_type) { create(:measure_type, trade_movement_code: 2) }
        let(:measure) { create(:measure, measure_type: measure_type) }

        it 'returns Both' do
          result = service.send(:import_export, measure)
          expect(result).to eq('Both')
        end
      end

      context 'when measure has unknown trade_movement_code' do
        let(:measure_type) { create(:measure_type, trade_movement_code: 99) }
        let(:measure) { create(:measure, measure_type: measure_type) }

        it 'returns empty string' do
          result = service.send(:import_export, measure)
          expect(result).to eq('')
        end
      end
    end

    describe '#geo_area' do
      context 'when geo_area is blank' do
        it 'returns N/A' do
          result = service.send(:geo_area, nil)
          expect(result).to eq('N/A')
        end
      end

      context 'when geo_area is erga_omnes' do
        let(:geographical_area) { create(:geographical_area, :erga_omnes, :with_description) }

        it 'returns All countries with ID' do
          result = service.send(:geo_area, geographical_area)
          expect(result).to eq('All countries (1011)')
        end
      end

      context 'when geo_area is a specific country' do
        let(:geographical_area) do
          create(:geographical_area, :with_description, geographical_area_id: 'FR')
        end

        before do
          # Manually set the description to 'France' since the factory generates random text
          geographical_area.geographical_area_description.update(description: 'France')
        end

        it 'returns country description with ID' do
          result = service.send(:geo_area, geographical_area)
          expect(result).to eq('France (FR)')
        end
      end

      context 'when there are excluded geographical areas' do
        let(:geographical_area) { create(:geographical_area, :erga_omnes, :with_description) }
        let(:excluded_area1) do
          create(:geographical_area, :with_description).tap do |area|
            area.geographical_area_description.update(description: 'United States')
          end
        end
        let(:excluded_area2) do
          create(:geographical_area, :with_description).tap do |area|
            area.geographical_area_description.update(description: 'Canada')
          end
        end
        let(:excluded_areas) { [excluded_area1, excluded_area2] }

        it 'includes excluded areas in description' do
          result = service.send(:geo_area, geographical_area, excluded_areas)
          expect(result).to eq('All countries (1011) excluding United States, Canada')
        end
      end
    end

    describe '#format_change_type' do
      let(:tariff_change) { build(:tariff_change, type: 'Commodity', action: action) }

      context 'when action is creation' do
        let(:action) { 'creation' }

        it 'returns Type Added' do
          result = service.send(:format_change_type, tariff_change)
          expect(result).to eq('Commodity Added')
        end
      end

      context 'when action is update' do
        let(:action) { 'update' }

        it 'returns Type Updated' do
          result = service.send(:format_change_type, tariff_change)
          expect(result).to eq('Commodity Updated')
        end
      end

      context 'when action is ending' do
        let(:action) { 'ending' }

        it 'returns Type Ending' do
          result = service.send(:format_change_type, tariff_change)
          expect(result).to eq('Commodity Ending')
        end
      end

      context 'when action is deletion' do
        let(:action) { 'deletion' }

        it 'returns Type Deleted' do
          result = service.send(:format_change_type, tariff_change)
          expect(result).to eq('Commodity Deleted')
        end
      end

      context 'when action is unknown' do
        let(:action) { 'unknown_action' }

        it 'returns humanized action' do
          result = service.send(:format_change_type, tariff_change)
          expect(result).to eq('Unknown action')
        end
      end
    end

    describe '#ott_url' do
      let(:tariff_change) do
        build(:tariff_change,
              goods_nomenclature_item_id: '0202000000',
              date_of_effect: Date.parse('2024-08-15'))
      end

      it 'builds the correct OTT URL with date parameters' do
        result = service.send(:ott_url, tariff_change)
        expected_url = 'https://www.trade-tariff.service.gov.uk/commodities/0202000000?day=15&month=8&year=2024'
        expect(result).to eq(expected_url)
      end
    end

    describe '#api_url' do
      let(:tariff_change) do
        build(:tariff_change, goods_nomenclature_item_id: '0202000000')
      end

      it 'builds the correct API URL' do
        result = service.send(:api_url, tariff_change)
        expected_url = 'https://www.trade-tariff.service.gov.uk/uk/api/commodities/0202000000'
        expect(result).to eq(expected_url)
      end
    end

    describe '#describe_change' do
      let(:goods_nomenclature) { create(:goods_nomenclature, goods_nomenclature_item_id: '0101010100') }
      let(:tariff_change) { build(:tariff_change, type: change_type, action: 'creation', goods_nomenclature: goods_nomenclature) }
      let(:measure) { nil }

      context 'when type is Commodity' do
        let(:change_type) { 'Commodity' }

        it 'returns the commodity code for creation action' do
          result = service.send(:describe_change, tariff_change, measure)
          expect(result).to eq('0101010100')
        end
      end

      context 'when type is CommodityDescription' do
        let(:change_type) { 'CommodityDescription' }
        let(:goods_nomenclature_description) do
          create(:goods_nomenclature_description,
                 goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                 description: 'Test description')
        end

        before do
          goods_nomenclature_description
          allow(TimeMachine).to receive(:at).and_yield
          allow(goods_nomenclature).to receive(:goods_nomenclature_description).and_return(goods_nomenclature_description)
          allow(goods_nomenclature_description).to receive(:csv_formatted_description).and_return('Test description')
        end

        it 'returns the commodity description for creation action' do
          result = service.send(:describe_change, tariff_change, measure)
          expect(result).to eq('Test description')
        end
      end

      context 'when type is Measure' do
        let(:change_type) { 'Measure' }
        let(:measure_type) { create(:measure_type) }
        let(:measure) { create(:measure, measure_type: measure_type) }

        before do
          allow(measure_type).to receive(:description).and_return('Third country duty')
        end

        it 'returns the measure type description for creation action' do
          result = service.send(:describe_change, tariff_change, measure)
          expect(result).to eq('Third country duty')
        end
      end

      context 'when type is unknown' do
        let(:change_type) { 'UnknownType' }

        it 'returns formatted type and action' do
          tariff_change = build(:tariff_change, type: 'UnknownType', action: 'update')
          result = service.send(:describe_change, tariff_change, measure)
          expect(result).to eq('UnknownType update')
        end
      end
    end

    describe '#describe_commodity_change' do
      let(:commodity) { create(:goods_nomenclature, goods_nomenclature_item_id: '0101010100') }
      let(:tariff_change) { build(:tariff_change, action: action) }

      context 'when action is not update' do
        let(:action) { 'creation' }

        it 'returns commodity code' do
          result = service.send(:describe_commodity_change, tariff_change, commodity)
          expect(result).to eq('0101010100')
        end
      end
    end

    describe '#describe_commodity_description_change' do
      let(:commodity) { create(:goods_nomenclature) }
      let(:tariff_change) { build(:tariff_change, action: action, goods_nomenclature_sid: commodity.goods_nomenclature_sid) }

      context 'when action is creation, ending, or deletion' do
        %w[creation ending deletion].each do |test_action|
          context "when action is #{test_action}" do
            let(:action) { test_action }
            let(:goods_nomenclature_description) do
              create(:goods_nomenclature_description,
                     goods_nomenclature_sid: commodity.goods_nomenclature_sid,
                     description: 'Test description')
            end

            before do
              goods_nomenclature_description
              allow(TimeMachine).to receive(:at).and_yield
              allow(commodity).to receive(:goods_nomenclature_description).and_return(goods_nomenclature_description)
              allow(goods_nomenclature_description).to receive(:csv_formatted_description).and_return('Test description')
            end

            it 'returns commodity description' do
              result = service.send(:describe_commodity_description_change, tariff_change, commodity)
              expect(result).to eq('Test description')
            end
          end
        end
      end
    end

    describe '#describe_measure_change' do
      let(:measure_type) { create(:measure_type) }
      let(:measure) { create(:measure, measure_type: measure_type) }
      let(:tariff_change) { build(:tariff_change, action: action) }

      before do
        allow(measure_type).to receive(:description).and_return('Third country duty')
      end

      context 'when action is not update' do
        let(:action) { 'creation' }

        it 'returns measure type description' do
          result = service.send(:describe_measure_change, tariff_change, measure)
          expect(result).to eq('Third country duty')
        end
      end
    end

    describe '#get_changes' do
      let(:measure) { create(:measure) }

      context 'when record has no previous_record' do
        it 'returns array with nil change and empty changes' do
          allow(measure).to receive(:previous_record).and_return(nil)

          result = service.send(:get_changes, measure)
          expect(result).to eq([nil, []])
        end
      end

      context 'when record has previous_record' do
        let(:previous_measure) { create(:measure) }

        before do
          allow(measure).to receive_messages(previous_record: previous_measure, values: {
            id: 1,
            validity_start_date: Date.current,
            validity_end_date: nil,
            measure_type_id: '103',
          })
        end

        it 'returns changes between current and previous record' do
          result = service.send(:get_changes, measure)
          expect(result).to be_an(Array)
          expect(result.length).to eq(2)
        end
      end
    end
  end
end

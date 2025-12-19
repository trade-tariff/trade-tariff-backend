RSpec.describe TariffChangesService::TransformRecords do
  subject(:service) { described_class.new(operation_date, goods_nomenclature_sids) }

  let(:operation_date) { Date.parse('2024-08-12') }
  let(:goods_nomenclature_sids) { nil }

  describe '.call' do
    it 'creates an instance and calls #call' do
      instance = described_class.new(operation_date, goods_nomenclature_sids)
      allow(described_class).to receive(:new).with(operation_date, goods_nomenclature_sids).and_return(instance)
      allow(instance).to receive(:call).and_return([])

      result = described_class.call(operation_date, goods_nomenclature_sids)

      expect(described_class).to have_received(:new).with(operation_date, goods_nomenclature_sids)
      expect(instance).to have_received(:call)
      expect(result).to eq([])
    end
  end

  describe '#initialize' do
    it 'sets the operation_date' do
      expect(service.operation_date).to eq(operation_date)
    end

    it 'sets the goods_nomenclature_sids' do
      service_with_sids = described_class.new(operation_date, [123, 456])
      expect(service_with_sids.goods_nomenclature_sids).to eq([123, 456])
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
          date_of_effect: '15/08/2024',
          import_export: 'N/A',
          geo_area: 'N/A',
          measure_type: 'N/A',
          additional_code: 'N/A',
          change_detail: 'New declarable commodity will begin',
        )
      end

      it 'includes all required fields' do
        result = service.call
        record = result.first

        expected_keys = %i[
          import_export
          geo_area
          measure_type
          additional_code
          chapter
          commodity_code
          commodity_code_description
          type_of_change
          change_detail
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

    context 'when filtering by goods_nomenclature_sids' do
      let(:goods_nomenclature_sids) { [goods_nomenclature1.goods_nomenclature_sid] }
      let(:goods_nomenclature1) do
        create(:goods_nomenclature,
               goods_nomenclature_item_id: '0101010100',
               validity_start_date: 1.day.ago)
      end
      let(:goods_nomenclature2) do
        create(:goods_nomenclature,
               goods_nomenclature_item_id: '0202020200',
               validity_start_date: 1.day.ago)
      end

      before do
        goods_nomenclature1
        goods_nomenclature2
        create(:goods_nomenclature_description, goods_nomenclature_sid: goods_nomenclature1.goods_nomenclature_sid)
        create(:goods_nomenclature_description, goods_nomenclature_sid: goods_nomenclature2.goods_nomenclature_sid)
        create(:tariff_change,
               operation_date: operation_date,
               goods_nomenclature_sid: goods_nomenclature1.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature1.goods_nomenclature_item_id)
        create(:tariff_change,
               operation_date: operation_date,
               goods_nomenclature_sid: goods_nomenclature2.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature2.goods_nomenclature_item_id)
      end

      it 'returns only tariff changes matching the given sids' do
        result = service.call

        expect(result.size).to eq(1)
        expect(result.first[:commodity_code]).to eq('0101010100')
      end
    end

    context 'when tariff change is commodity ending' do
      let(:goods_nomenclature) do
        create(:goods_nomenclature,
               goods_nomenclature_item_id: '0303030300',
               validity_start_date: 1.year.ago,
               validity_end_date: operation_date)
      end

      before do
        goods_nomenclature
        create(:goods_nomenclature_description, goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
        create(:tariff_change,
               operation_date: operation_date,
               type: 'Commodity',
               action: 'ending',
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id)
      end

      it 'includes the correct change_detail for ending' do
        result = service.call
        record = result.first

        expect(record[:type_of_change]).to eq('Commodity End Date Updated')
        expect(record[:change_detail]).to eq('Commodity will stop being declarable')
      end
    end

    context 'when tariff change is commodity description update' do
      let(:goods_nomenclature) { create(:goods_nomenclature, goods_nomenclature_item_id: '0404040400') }
      let(:description_period) do
        create(:goods_nomenclature_description_period,
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_description_period_sid: 789)
      end
      let(:description) do
        create(:goods_nomenclature_description,
               goods_nomenclature_description_period_sid: 789,
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               description: 'Updated commodity description')
      end

      before do
        goods_nomenclature
        description_period
        description
        create(:tariff_change,
               operation_date: operation_date,
               type: 'GoodsNomenclatureDescription',
               action: 'update',
               object_sid: 789,
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id)
      end

      it 'includes the new description in change_detail' do
        result = service.call
        record = result.first

        expect(record[:type_of_change]).to eq('Commodity Description Updated')
        expect(record[:change_detail]).to eq('New description: Updated commodity description')
      end
    end

    context 'when tariff change has measure metadata' do
      let(:measure_type) { create(:measure_type, trade_movement_code: 0) }
      let(:measure) { create(:measure, measure_type: measure_type) }
      let(:goods_nomenclature) { create(:goods_nomenclature, goods_nomenclature_sid: measure.goods_nomenclature_sid) }
      let(:geographical_area) { create(:geographical_area, :with_description, geographical_area_id: 'FR') }
      let(:metadata) do
        {
          'measure' => {
            'measure_type_id' => measure.measure_type_id,
            'trade_movement_code' => 0,
            'geographical_area_id' => geographical_area.geographical_area_id,
            'excluded_geographical_area_ids' => [],
            'additional_code' => 'A123',
          },
        }.to_json
      end
      let(:tariff_change) do
        create(:tariff_change,
               operation_date: operation_date,
               type: 'Measure',
               action: 'creation',
               object_sid: measure.measure_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               metadata: metadata)
      end

      before do
        goods_nomenclature
        geographical_area
        # Update description after creation to ensure it's persisted
        desc = geographical_area.geographical_area_description
        desc.description = 'France'
        desc.save
        create(:goods_nomenclature_description, goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
        tariff_change
      end

      it 'includes measure information from metadata' do
        result = service.call
        record = result.first

        expect(record[:import_export]).to eq('Import')
        expect(record[:geo_area]).to match(/\(FR\)/)
        expect(record[:type_of_change]).to eq('Measure Added')
        expect(record[:additional_code]).to eq('A123')
      end

      it 'caches geographical areas to avoid N+1 queries' do
        # This test verifies the cache is set during load_tariff_changes
        service.call

        # Access the cache that was set
        cache = service.send(:geo_area_cache)
        expect(cache).to be_a(Hash)
        expect(cache[geographical_area.geographical_area_id]).to eq(geographical_area)
      end

      it 'includes correct change_detail for measure creation' do
        result = service.call
        record = result.first

        expect(record[:change_detail]).to eq('Measure will begin')
      end
    end

    context 'when tariff change is measure ending' do
      let(:measure_type) { create(:measure_type, trade_movement_code: 1) }
      let(:measure) { create(:measure, measure_type: measure_type) }
      let(:goods_nomenclature) { create(:goods_nomenclature, goods_nomenclature_sid: measure.goods_nomenclature_sid) }

      before do
        goods_nomenclature
        create(:goods_nomenclature_description, goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
        create(:tariff_change,
               operation_date: operation_date,
               type: 'Measure',
               action: 'ending',
               object_sid: measure.measure_sid,
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id)
      end

      it 'includes correct change_detail for measure ending' do
        result = service.call
        record = result.first

        expect(record[:type_of_change]).to eq('Measure End Date Updated')
        expect(record[:change_detail]).to eq('Measure will end')
      end
    end

    context 'when tariff change is measure update' do
      let(:measure_type) { create(:measure_type, trade_movement_code: 0) }
      let(:measure) { create(:measure, measure_type: measure_type) }
      let(:goods_nomenclature) { create(:goods_nomenclature, goods_nomenclature_sid: measure.goods_nomenclature_sid) }

      before do
        goods_nomenclature
        create(:goods_nomenclature_description, goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
        create(:tariff_change,
               operation_date: operation_date,
               type: 'Measure',
               action: 'update',
               object_sid: measure.measure_sid,
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id)
      end

      it 'includes correct change_detail for measure update' do
        result = service.call
        record = result.first

        expect(record[:type_of_change]).to eq('Measure Updated')
        expect(record[:change_detail]).to eq('Measure has been updated other than a change to end date')
      end
    end

    context 'when tariff change is measure deletion' do
      let(:measure_type) { create(:measure_type, trade_movement_code: 0) }
      let(:measure) { create(:measure, measure_type: measure_type) }
      let(:goods_nomenclature) { create(:goods_nomenclature, goods_nomenclature_sid: measure.goods_nomenclature_sid) }

      before do
        goods_nomenclature
        create(:goods_nomenclature_description, goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
        create(:tariff_change,
               operation_date: operation_date,
               type: 'Measure',
               action: 'deletion',
               object_sid: measure.measure_sid,
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id)
      end

      it 'includes correct change_detail for measure deletion' do
        result = service.call
        record = result.first

        expect(record[:type_of_change]).to eq('Measure Deleted')
        expect(record[:change_detail]).to eq('Measure will no longer begin')
      end
    end
  end

  describe 'private methods' do
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

        it 'returns Type End Date Updated' do
          result = service.send(:format_change_type, tariff_change)
          expect(result).to eq('Commodity End Date Updated')
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
      let(:presented_change) { TariffChangesService::Presenter.new(tariff_change) }

      context 'when type is Commodity' do
        let(:tariff_change) { build(:tariff_change, type: 'Commodity', action: 'creation') }

        it 'delegates to describe_commodity_change' do
          result = service.send(:describe_change, presented_change)
          expect(result).to eq('New declarable commodity will begin')
        end
      end

      context 'when type is GoodsNomenclatureDescription' do
        let(:goods_nomenclature) { create(:goods_nomenclature) }
        let(:tariff_change) do
          build(:tariff_change,
                type: 'GoodsNomenclatureDescription',
                action: 'update',
                object_sid: 123,
                goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
        end
        let(:description) { instance_double(GoodsNomenclatureDescription, csv_formatted_description: 'Test description') }

        before do
          service.instance_variable_set(:@gn_descriptions_cache, { 123 => description })
        end

        it 'delegates to describe_commodity_description_change' do
          result = service.send(:describe_change, presented_change)
          expect(result).to eq('New description: Test description')
        end
      end

      context 'when type is Measure' do
        let(:tariff_change) { build(:tariff_change, type: 'Measure', action: 'creation') }

        it 'delegates to describe_measure_change' do
          result = service.send(:describe_change, presented_change)
          expect(result).to eq('Measure will begin')
        end
      end

      context 'when type is unknown' do
        let(:tariff_change) { build(:tariff_change, type: 'UnknownType', action: 'creation') }

        it 'returns a generic description' do
          result = service.send(:describe_change, presented_change)
          expect(result).to eq('UnknownType creation')
        end
      end
    end

    describe '#describe_commodity_change' do
      let(:presented_change) { TariffChangesService::Presenter.new(tariff_change) }

      context 'when action is creation' do
        let(:tariff_change) { build(:tariff_change, type: 'Commodity', action: 'creation') }

        it 'returns creation message' do
          result = service.send(:describe_commodity_change, presented_change)
          expect(result).to eq('New declarable commodity will begin')
        end
      end

      context 'when action is ending' do
        let(:tariff_change) { build(:tariff_change, type: 'Commodity', action: 'ending') }

        it 'returns ending message' do
          result = service.send(:describe_commodity_change, presented_change)
          expect(result).to eq('Commodity will stop being declarable')
        end
      end

      context 'when action is update' do
        let(:tariff_change) { build(:tariff_change, type: 'Commodity', action: 'update') }

        it 'returns generic message' do
          result = service.send(:describe_commodity_change, presented_change)
          expect(result).to eq('Commodity change')
        end
      end

      context 'when action is deletion' do
        let(:tariff_change) { build(:tariff_change, type: 'Commodity', action: 'deletion') }

        it 'returns generic message' do
          result = service.send(:describe_commodity_change, presented_change)
          expect(result).to eq('Commodity change')
        end
      end
    end

    describe '#describe_commodity_description_change' do
      let(:goods_nomenclature) { create(:goods_nomenclature) }
      let(:tariff_change) do
        build(:tariff_change,
              type: 'GoodsNomenclatureDescription',
              action: 'update',
              object_sid: 456,
              goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
      end
      let(:presented_change) { TariffChangesService::Presenter.new(tariff_change) }
      let(:description) { instance_double(GoodsNomenclatureDescription, csv_formatted_description: 'Live animals; horses') }

      before do
        service.instance_variable_set(:@gn_descriptions_cache, { 456 => description })
      end

      it 'returns the new description with prefix' do
        result = service.send(:describe_commodity_description_change, presented_change)
        expect(result).to eq('New description: Live animals; horses')
      end

      context 'when description is not in cache' do
        before do
          service.instance_variable_set(:@gn_descriptions_cache, {})
        end

        it 'handles missing description gracefully' do
          expect {
            service.send(:describe_commodity_description_change, presented_change)
          }.to raise_error(KeyError)
        end
      end

      context 'when cache is nil' do
        before do
          service.instance_variable_set(:@gn_descriptions_cache, nil)
        end

        it 'raises an error when trying to fetch from nil cache' do
          expect {
            service.send(:describe_commodity_description_change, presented_change)
          }.to raise_error(NoMethodError)
        end
      end
    end

    describe '#describe_measure_change' do
      let(:presented_change) { TariffChangesService::Presenter.new(tariff_change) }

      context 'when action is creation' do
        let(:tariff_change) { build(:tariff_change, type: 'Measure', action: 'creation') }

        it 'returns creation message' do
          result = service.send(:describe_measure_change, presented_change)
          expect(result).to eq('Measure will begin')
        end
      end

      context 'when action is ending' do
        let(:tariff_change) { build(:tariff_change, type: 'Measure', action: 'ending') }

        it 'returns ending message' do
          result = service.send(:describe_measure_change, presented_change)
          expect(result).to eq('Measure will end')
        end
      end

      context 'when action is update' do
        let(:tariff_change) { build(:tariff_change, type: 'Measure', action: 'update') }

        it 'returns update message' do
          result = service.send(:describe_measure_change, presented_change)
          expect(result).to eq('Measure has been updated other than a change to end date')
        end
      end

      context 'when action is deletion' do
        let(:tariff_change) { build(:tariff_change, type: 'Measure', action: 'deletion') }

        it 'returns deletion message' do
          result = service.send(:describe_measure_change, presented_change)
          expect(result).to eq('Measure will no longer begin')
        end
      end

      context 'when action is unknown' do
        let(:tariff_change) { build(:tariff_change, type: 'Measure', action: 'unknown') }

        it 'returns generic message' do
          result = service.send(:describe_measure_change, presented_change)
          expect(result).to eq('Measure change')
        end
      end
    end
  end
end

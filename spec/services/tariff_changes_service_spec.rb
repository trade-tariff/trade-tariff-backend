RSpec.describe TariffChangesService do
  let(:date) { Date.new(2025, 1, 15) }
  let(:service) { described_class.new(date) }

  describe '.generate' do
    let(:service) { instance_double(described_class) }

    context 'when called without a date' do
      it 'uses today as the default date' do
        freeze_time do
          allow(described_class).to receive(:new).with(Time.zone.today).and_return(service)
          allow(service).to receive(:all_changes)

          described_class.generate

          expect(described_class).to have_received(:new).with(Time.zone.today)
          expect(service).to have_received(:all_changes)
        end
      end
    end

    context 'when called with a specific date' do
      it 'uses the provided date' do
        allow(described_class).to receive(:new).with(date).and_return(service)
        allow(service).to receive(:all_changes)

        described_class.generate(date)

        expect(described_class).to have_received(:new).with(date)
        expect(service).to have_received(:all_changes)
      end
    end
  end

  describe '.generate_report_for' do
    let(:date) { Date.new(2024, 8, 11) }
    let(:change_records) { [{ dummy: 'data' }] }
    let(:package) { instance_double(Axlsx::Package) }
    let(:mailer_double) { instance_double(ActionMailer::MessageDelivery) }

    before do
      allow(TariffChangesService::TransformRecords).to receive(:call).with(date).and_return(change_records)
      allow(TariffChangesService::ExcelGenerator).to receive(:call).with(change_records, date).and_return(package)
    end

    context 'when in development environment' do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
        allow(package).to receive(:serialize)
      end

      it 'transforms records for the given date' do
        described_class.generate_report_for(date)

        expect(TariffChangesService::TransformRecords).to have_received(:call).with(date)
      end

      it 'generates Excel package with the transformed records' do
        described_class.generate_report_for(date)

        expect(TariffChangesService::ExcelGenerator).to have_received(:call).with(change_records, date)
      end

      it 'serializes the package to a file with correct filename' do
        described_class.generate_report_for(date)

        expected_filename = "commodity_watchlist_#{date.strftime('%Y_%m_%d')}.xlsx"
        expect(package).to have_received(:serialize).with(expected_filename)
      end

      it 'does not send an email' do
        allow(ReportsMailer).to receive(:commodity_watchlist)

        described_class.generate_report_for(date)

        expect(ReportsMailer).not_to have_received(:commodity_watchlist)
      end
    end

    context 'when in non-development environment' do
      before do
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(ReportsMailer).to receive(:commodity_watchlist).with(date, package).and_return(mailer_double)
        allow(mailer_double).to receive(:deliver_now)
      end

      it 'transforms records for the given date' do
        described_class.generate_report_for(date)

        expect(TariffChangesService::TransformRecords).to have_received(:call).with(date)
      end

      it 'generates Excel package with the transformed records' do
        described_class.generate_report_for(date)

        expect(TariffChangesService::ExcelGenerator).to have_received(:call).with(change_records, date)
      end

      it 'sends email with the package' do
        described_class.generate_report_for(date)

        expect(ReportsMailer).to have_received(:commodity_watchlist).with(date, package)
        expect(mailer_double).to have_received(:deliver_now)
      end

      it 'does not serialize the package to a file' do
        allow(package).to receive(:serialize)

        described_class.generate_report_for(date)

        expect(package).not_to have_received(:serialize)
      end
    end
  end

  describe '#initialize' do
    it 'sets the date and initializes empty collections' do
      expect(service.date).to eq(date)
      expect(service.tariff_change_records).to eq([])
      expect(service.instance_variable_get(:@changes)).to eq({})
    end
  end

  describe '#all_changes' do
    let(:commodity_changes) { [commodity_change] }
    let(:commodity_description_changes) { [commodity_description_change] }
    let(:measure_changes) { [measure_change] }
    let(:commodity_change) do
      {
        type: 'Commodity',
        goods_nomenclature_item_id: '0101010100',
        object_sid: 12_345,
        goods_nomenclature_sid: 12_345,
        action: 'creation',
        date_of_effect: date,
        validity_start_date: date,
        validity_end_date: nil,
      }
    end
    let(:commodity_description_change) do
      {
        type: 'CommodityDescription',
        goods_nomenclature_item_id: '0102020200',
        object_sid: 23_456,
        goods_nomenclature_sid: 23_456,
        action: 'update',
        date_of_effect: date,
        validity_start_date: date,
        validity_end_date: nil,
      }
    end
    let(:measure_change) do
      {
        type: 'Measure',
        object_sid: 54_321,
        goods_nomenclature_sid: 67_890,
        action: 'creation',
        date_of_effect: date,
        validity_start_date: date,
        validity_end_date: nil,
      }
    end

    before do
      allow(TariffChangesService::CommodityChanges).to receive(:collect).with(date).and_return(commodity_changes)
      allow(TariffChangesService::CommodityDescriptionChanges).to receive(:collect).with(date).and_return(commodity_description_changes)
      allow(TariffChangesService::MeasureChanges).to receive(:collect).with(date).and_return(measure_changes)
    end

    it 'executes within a TimeMachine context' do
      allow(TimeMachine).to receive(:at).with(date).and_yield
      other_service = described_class.new(date)

      other_service.all_changes

      expect(TimeMachine).to have_received(:at).with(date)
    end

    it 'collects commodity, commodity description and measure changes' do
      other_service = described_class.new(date)

      other_service.all_changes

      expect(TariffChangesService::CommodityChanges).to have_received(:collect).with(date)
      expect(TariffChangesService::CommodityDescriptionChanges).to have_received(:collect).with(date)
      expect(TariffChangesService::MeasureChanges).to have_received(:collect).with(date)
    end

    it 'generates commodity change records' do
      other_service = described_class.new(date)
      allow(other_service).to receive(:generate_commodity_change_records).and_return(spy)

      other_service.all_changes

      expect(other_service).to have_received(:generate_commodity_change_records)
    end

    it 'deletes existing tariff changes for the operation date' do
      allow(TariffChange).to receive(:delete_for).with(operation_date: date)
      allow(TariffChange).to receive(:multi_insert)

      service.all_changes

      expect(TariffChange).to have_received(:delete_for).with(operation_date: date)
    end

    it 'persists tariff change records when records exist' do
      allow(TariffChangesService::CommodityChanges).to receive(:collect).with(date).and_return([])
      allow(TariffChangesService::CommodityDescriptionChanges).to receive(:collect).with(date).and_return([])
      allow(TariffChangesService::MeasureChanges).to receive(:collect).with(date).and_return([])

      test_record = {
        type: 'Commodity',
        object_sid: 12_345,
        goods_nomenclature_item_id: '0101010100',
        goods_nomenclature_sid: 12_345,
        action: 'creation',
        operation_date: date,
        date_of_effect: date,
        validity_start_date: date,
        validity_end_date: nil,
      }
      other_service = described_class.new(date)
      other_service.instance_variable_set(:@tariff_change_records, [test_record])
      allow(TariffChange).to receive(:delete_for)
      allow(TariffChange).to receive(:multi_insert)

      other_service.all_changes

      expect(TariffChange).to have_received(:multi_insert).with([test_record])
    end

    it 'does not call multi_insert when no records exist' do
      allow(TariffChangesService::CommodityChanges).to receive(:collect).with(date).and_return([])
      allow(TariffChangesService::CommodityDescriptionChanges).to receive(:collect).with(date).and_return([])
      allow(TariffChangesService::MeasureChanges).to receive(:collect).with(date).and_return([])

      other_service = described_class.new(date)
      allow(TariffChange).to receive(:delete_for)
      allow(TariffChange).to receive(:multi_insert)

      other_service.all_changes

      expect(TariffChange).not_to have_received(:multi_insert)
    end

    it 'returns a formatted hash with date, count and changes' do
      TimeMachine.at(date) do
        allow(TariffChangesService::CommodityChanges).to receive(:collect).with(date).and_return([commodity_change])
        allow(TariffChangesService::CommodityDescriptionChanges).to receive(:collect).with(date).and_return([])
        allow(TariffChangesService::MeasureChanges).to receive(:collect).with(date).and_return([])
        other_service = described_class.new(date)
        allow(other_service).to receive(:add_change_record) do |change, item_id, sid|
          other_service.tariff_change_records << {
            type: change[:type],
            object_sid: change[:object_sid],
            goods_nomenclature_item_id: item_id,
            goods_nomenclature_sid: sid,
            action: change[:action],
            operation_date: date,
            date_of_effect: change[:date_of_effect],
            validity_start_date: change[:validity_start_date],
            validity_end_date: change[:validity_end_date],
          }
        end

        result = other_service.all_changes

        expect(result).to include(
          date: date.strftime('%Y_%m_%d'),
          count: 1,
        )
        expect(result[:changes]).to be_an(Array)
      end
    end

    it 'sorts changes by goods nomenclature item id, type, and action' do
      allow(TariffChangesService::CommodityChanges).to receive(:collect).with(date).and_return([])
      allow(TariffChangesService::CommodityDescriptionChanges).to receive(:collect).with(date).and_return([])
      allow(TariffChangesService::MeasureChanges).to receive(:collect).with(date).and_return([])

      change_1 = {
        goods_nomenclature_item_id: '0102000000',
        type: 'Commodity',
        action: 'creation',
        object_sid: 12_345,
        goods_nomenclature_sid: 12_345,
        operation_date: date,
        date_of_effect: date,
        validity_start_date: date,
        validity_end_date: nil,
      }
      change_2 = {
        goods_nomenclature_item_id: '0101000000',
        type: 'Measure',
        action: 'update',
        object_sid: 23_456,
        goods_nomenclature_sid: 23_456,
        operation_date: date,
        date_of_effect: date,
        validity_start_date: date,
        validity_end_date: nil,
      }
      change_3 = {
        goods_nomenclature_item_id: '0101000000',
        type: 'Commodity',
        action: 'creation',
        object_sid: 34_567,
        goods_nomenclature_sid: 34_567,
        operation_date: date,
        date_of_effect: date,
        validity_start_date: date,
        validity_end_date: nil,
      }

      other_service = described_class.new(date)
      other_service.instance_variable_set(:@tariff_change_records, [change_1, change_2, change_3])
      allow(TariffChange).to receive(:delete_for)
      allow(TariffChange).to receive(:multi_insert)

      result = other_service.all_changes

      expect(result[:changes]).to eq([change_3, change_2, change_1])
    end
  end

  describe '#generate_commodity_change_records' do
    let(:commodity_change) do
      {
        type: 'Commodity',
        goods_nomenclature_item_id: '0101010100',
        object_sid: 12_345,
      }
    end
    let(:commodity_description_change) do
      {
        type: 'CommodityDescription',
        goods_nomenclature_item_id: '0102020200',
        object_sid: 23_456,
        goods_nomenclature_sid: 23_456,
        action: 'update',
      }
    end
    let(:measure_change) do
      {
        type: 'Measure',
        object_sid: 54_321,
        goods_nomenclature_sid: 67_890,
      }
    end
    let(:goods_nomenclature) { create(:commodity, :declarable, goods_nomenclature_sid: 67_890) }
    let(:descendant) { create(:commodity, :declarable) }

    before do
      service.instance_variable_set(:@changes, {
        commodities: [commodity_change],
        commodity_descriptions: [commodity_description_change],
        measures: [measure_change],
      })
    end

    context 'when processing commodity changes' do
      it 'adds change records for each commodity change' do
        service.generate_commodity_change_records

        expect(service.tariff_change_records).to include(
          hash_including(
            type: commodity_change[:type],
            goods_nomenclature_item_id: commodity_change[:goods_nomenclature_item_id],
            goods_nomenclature_sid: commodity_change[:object_sid],
          ),
        )
      end
    end

    context 'when processing commodity description changes' do
      it 'adds change records for commodity description changes' do
        service.generate_commodity_change_records

        expect(service.tariff_change_records).to include(
          hash_including(
            type: commodity_description_change[:type],
            goods_nomenclature_item_id: commodity_description_change[:goods_nomenclature_item_id],
            goods_nomenclature_sid: commodity_description_change[:goods_nomenclature_sid],
          ),
        )
      end

      it 'skips commodity description changes when there is a matching commodity change' do
        allow(service).to receive(:matching_commodity_change?).with(commodity_description_change[:goods_nomenclature_sid], commodity_description_change[:action]).and_return(true)

        service.generate_commodity_change_records

        commodity_description_records = service.tariff_change_records.select { |r| r[:type] == 'CommodityDescription' }
        expect(commodity_description_records).to be_empty
      end
    end

    context 'when processing measure changes' do
      context 'when goods nomenclature is not found' do
        it 'does not add measure change records but processes other changes' do
          # Create a measure change that references a non-existent goods_nomenclature_sid
          service.instance_variable_set(:@changes, {
            commodities: [commodity_change],
            commodity_descriptions: [commodity_description_change],
            measures: [{
              type: 'Measure',
              object_sid: 54_321,
              goods_nomenclature_sid: 99_999,
            }],
          })

          initial_count = service.tariff_change_records.count
          service.generate_commodity_change_records

          expect(service.tariff_change_records.count).to eq(initial_count + 2)
          expect(service.tariff_change_records.map { |r| r[:type] }).to match_array(%w[Commodity CommodityDescription])
        end
      end

      context 'when goods nomenclature is declarable' do
        before do
          goods_nomenclature
        end

        it 'adds change record for the declarable goods nomenclature' do
          other_service = described_class.new(date)
          allow(other_service).to receive(:matching_commodity_change?).and_return(false)

          other_service.instance_variable_set(:@changes, service.instance_variable_get(:@changes))

          other_service.generate_commodity_change_records

          measure_records = other_service.tariff_change_records.select { |r| r[:type] == 'Measure' }
          expect(measure_records).to include(
            hash_including(
              type: 'Measure',
              goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
              goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
            ),
          )
        end
      end

      context 'when goods nomenclature is not declarable but has declarable descendants' do
        let(:non_declarable_parent) { create(:heading, goods_nomenclature_sid: 67_890) }
        let(:declarable_child) { create(:commodity, :declarable, parent: non_declarable_parent) }

        before do
          non_declarable_parent
          declarable_child
        end

        it 'adds change records for declarable descendants' do
          other_service = described_class.new(date)
          other_service.instance_variable_set(:@changes, service.instance_variable_get(:@changes))
          allow(other_service).to receive(:matching_commodity_change?).and_return(false)

          other_service.generate_commodity_change_records

          expect(other_service.tariff_change_records).to include(
            hash_including(
              type: 'Measure',
              goods_nomenclature_item_id: declarable_child.goods_nomenclature_item_id,
              goods_nomenclature_sid: declarable_child.goods_nomenclature_sid,
            ),
          )
        end
      end

      context 'when there is a matching commodity change' do
        before do
          goods_nomenclature
        end

        it 'does not add a change record' do
          other_service = described_class.new(date)
          other_service.instance_variable_set(:@changes, service.instance_variable_get(:@changes))
          allow(other_service).to receive(:matching_commodity_change?).and_return(false, true)

          other_service.generate_commodity_change_records

          expect(other_service.tariff_change_records).not_to include(hash_including(type: 'Measure', goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid))
        end
      end
    end
  end

  describe '#add_change_record' do
    let(:change) do
      {
        type: 'Commodity',
        object_sid: 98_765,
        action: 'creation',
        date_of_effect: date,
        validity_start_date: date,
        validity_end_date: nil,
      }
    end
    let(:gn_item_id) { '0101010100' }
    let(:gn_sid) { 12_345 }

    it 'adds a properly formatted change record with created_at timestamp' do
      freeze_time do
        service.add_change_record(change, gn_item_id, gn_sid)

        expected_record = {
          type: 'Commodity',
          object_sid: 98_765,
          goods_nomenclature_item_id: '0101010100',
          goods_nomenclature_sid: 12_345,
          action: 'creation',
          operation_date: date,
          date_of_effect: date,
          validity_start_date: date,
          validity_end_date: nil,
        }

        expect(service.tariff_change_records).to include(expected_record)
      end
    end

    it 'appends to existing records' do
      service.instance_variable_set(:@tariff_change_records, [{ existing: 'record' }])

      service.add_change_record(change, gn_item_id, gn_sid)

      expect(service.tariff_change_records.size).to eq(2)
    end
  end

  describe '#matching_commodity_change?' do
    let(:goods_nomenclature_sid) { 12_345 }

    before do
      service.instance_variable_set(:@tariff_change_records, [
        {
          goods_nomenclature_sid: 12_345,
          type: 'Commodity',
          action: 'creation',
        },
        {
          goods_nomenclature_sid: 67_890,
          type: 'Measure',
          action: 'update',
        },
      ])
    end

    it 'returns true when there is a matching commodity change' do
      result = service.matching_commodity_change?(goods_nomenclature_sid, 'creation')

      expect(result).to be true
    end

    it 'returns false when there is no matching commodity change' do
      result = service.matching_commodity_change?(goods_nomenclature_sid, 'deletion')

      expect(result).to be false
    end

    it 'returns false when goods_nomenclature_sid does not match' do
      different_sid = 99_999

      result = service.matching_commodity_change?(different_sid, 'creation')

      expect(result).to be false
    end

    it 'returns false when type is not Commodity' do
      service.tariff_change_records.first[:type] = 'Measure'

      result = service.matching_commodity_change?(goods_nomenclature_sid, 'creation')

      expect(result).to be false
    end

    it 'returns false when action does not match' do
      result = service.matching_commodity_change?(goods_nomenclature_sid, 'update')

      expect(result).to be false
    end
  end

  describe 'error handling' do
    before do
      allow(TariffChangesService::CommodityChanges).to receive(:collect).with(date).and_return([])
      allow(TariffChangesService::CommodityDescriptionChanges).to receive(:collect).with(date).and_return([])
      allow(TariffChangesService::MeasureChanges).to receive(:collect).with(date).and_return([])
    end

    it 'handles when CommodityChanges.collect returns nil' do
      allow(TariffChangesService::CommodityChanges).to receive(:collect).with(date).and_return(nil)

      expect { service.all_changes }.to raise_error(NoMethodError)
    end

    it 'handles when CommodityDescriptionChanges.collect returns nil' do
      allow(TariffChangesService::CommodityDescriptionChanges).to receive(:collect).with(date).and_return(nil)

      expect { service.all_changes }.to raise_error(NoMethodError)
    end

    it 'handles when MeasureChanges.collect returns nil' do
      allow(TariffChangesService::MeasureChanges).to receive(:collect).with(date).and_return(nil)

      expect { service.all_changes }.to raise_error(NoMethodError)
    end

    it 'handles empty collections gracefully' do
      allow(TariffChangesService::CommodityChanges).to receive(:collect).with(date).and_return([])
      allow(TariffChangesService::CommodityDescriptionChanges).to receive(:collect).with(date).and_return([])
      allow(TariffChangesService::MeasureChanges).to receive(:collect).with(date).and_return([])

      result = service.all_changes

      expect(result).to include(
        date: date.strftime('%Y_%m_%d'),
        count: 0,
        changes: [],
      )
    end
  end
end

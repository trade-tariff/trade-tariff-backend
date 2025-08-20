RSpec.describe DeltaReportService do
  subject(:service) { described_class.new(date) }

  let(:date) { Date.parse('2024-08-11') }

  describe '.generate' do
    subject(:result) { described_class.generate(date: date) }

    before do
      service_instance = instance_double(described_class, generate_report: expected_result)
      allow(described_class).to receive(:new).and_return(service_instance)
    end

    let(:expected_result) do
      {
        date: date,
        total_records: 2,
        commodity_changes: [
          { commodity_code: '0101000000', type: 'Measure' },
          { commodity_code: '0102000000', type: 'GoodsNomenclature' },
        ],
      }
    end

    it 'creates a new instance and calls generate_report' do
      expect(result).to eq(expected_result)
    end

    it 'defaults to today when no date provided' do
      travel_to(date) do
        expect(described_class.generate).to eq(expected_result)
      end
    end
  end

  describe '#initialize' do
    it 'sets the date' do
      expect(service.date).to eq(date)
    end

    it 'initializes changes as empty hash' do
      expect(service.instance_variable_get(:@changes)).to eq({})
    end
  end

  describe '#generate_report' do
    subject(:result) { service.generate_report }

    let(:commodity) do
      instance_double(
        Commodity,
        goods_nomenclature_item_id: '0101000000',
        chapter_short_code: '01',
        goods_nomenclature_description: instance_double(GoodsNomenclatureDescription, description: 'Test commodity'),
        declarable?: true,
      )
    end
    let(:mock_changes) do
      {
        goods_nomenclatures: [
          {
            type: 'GoodsNomenclature',
            goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
            description: 'Commodity added',
            date_of_effect: date,
            change: 'new',
          },
        ],
        measures: [],
        measure_components: [],
        measure_conditions: [],
        geographical_areas: [],
        certificates: [],
        additional_codes: [],
      }
    end

    let(:expected_commodity_change) do
      {
        type: 'GoodsNomenclature',
        operation_date: date,
        chapter: commodity.chapter_short_code,
        commodity_code: commodity.goods_nomenclature_item_id,
        commodity_code_description: commodity.goods_nomenclature_description.description,
        import_export: nil,
        geo_area: nil,
        additional_code: nil,
        duty_expression: nil,
        measure_type: nil,
        type_of_change: 'Commodity added',
        date_of_effect: date,
        change: 'new',
      }
    end

    before do
      allow(DeltaReportService::CommodityChanges).to receive(:collect).with(date).and_return(mock_changes[:goods_nomenclatures])
      allow(DeltaReportService::MeasureChanges).to receive(:collect).with(date).and_return(mock_changes[:measures])
      allow(DeltaReportService::MeasureComponentChanges).to receive(:collect).with(date).and_return(mock_changes[:measure_components])
      allow(DeltaReportService::MeasureConditionChanges).to receive(:collect).with(date).and_return(mock_changes[:measure_conditions])
      allow(DeltaReportService::GeographicalAreaChanges).to receive(:collect).with(date).and_return(mock_changes[:geographical_areas])
      allow(DeltaReportService::CertificateChanges).to receive(:collect).with(date).and_return(mock_changes[:certificates])
      allow(DeltaReportService::AdditionalCodeChanges).to receive(:collect).with(date).and_return(mock_changes[:additional_codes])
      allow(DeltaReportService::ExcelGenerator).to receive(:call).and_return(instance_double(Axlsx::Package))
      allow(TimeMachine).to receive(:now).and_yield

      actual_scope = instance_double(Sequel::Dataset)
      allow(GoodsNomenclature).to receive(:actual).and_return(actual_scope)
      allow(actual_scope).to receive(:where).with(goods_nomenclature_item_id: commodity.goods_nomenclature_item_id).and_return(actual_scope)
      allow(actual_scope).to receive(:first).and_return(commodity)
      allow(commodity).to receive(:declarable?).and_return(true)
    end

    it 'wraps the execution in TimeMachine.now block' do
      result
      expect(TimeMachine).to have_received(:now)
    end

    it 'collects all changes from various change classes' do
      result

      expect(DeltaReportService::CommodityChanges).to have_received(:collect).with(date)
      expect(DeltaReportService::MeasureChanges).to have_received(:collect).with(date)
      expect(DeltaReportService::MeasureComponentChanges).to have_received(:collect).with(date)
      expect(DeltaReportService::MeasureConditionChanges).to have_received(:collect).with(date)
      expect(DeltaReportService::GeographicalAreaChanges).to have_received(:collect).with(date)
      expect(DeltaReportService::CertificateChanges).to have_received(:collect).with(date)
      expect(DeltaReportService::AdditionalCodeChanges).to have_received(:collect).with(date)
    end

    it 'calls ExcelGenerator with commodity change records and date' do
      result
      expect(DeltaReportService::ExcelGenerator).to have_received(:call).with([expected_commodity_change], date)
    end

    it 'returns the expected report structure' do
      expect(result).to include(
        date: date,
        total_records: 1,
        commodity_changes: [expected_commodity_change],
      )
    end

    context 'when there are no changes' do
      let(:mock_changes) do
        {
          goods_nomenclatures: [],
          measures: [],
          measure_components: [],
          measure_conditions: [],
          geographical_areas: [],
          certificates: [],
          additional_codes: [],
        }
      end

      it 'returns empty commodity changes' do
        expect(result[:commodity_changes]).to be_empty
        expect(result[:total_records]).to eq(0)
      end
    end
  end

  describe '#find_affected_declarable_goods' do
    context 'when change type is Measure' do
      let(:change) { { type: 'Measure', goods_nomenclature_item_id: '0101000000' } }
      let(:declarable_commodity) { instance_double(Commodity, goods_nomenclature_item_id: '0101000000', declarable?: true) }

      before do
        actual_scope = instance_double(Sequel::Dataset)
        allow(GoodsNomenclature).to receive(:actual).and_return(actual_scope)
        allow(actual_scope).to receive(:where).with(goods_nomenclature_item_id: '0101000000').and_return(actual_scope)
        allow(actual_scope).to receive(:first).and_return(declarable_commodity)
        allow(declarable_commodity).to receive(:declarable?).and_return(true)
      end

      it 'returns declarable goods for the specified nomenclature item id' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is GoodsNomenclature' do
      let(:change) { { type: 'GoodsNomenclature', goods_nomenclature_item_id: '0101000000' } }
      let(:declarable_commodity) { instance_double(Commodity, goods_nomenclature_item_id: '0101000000', declarable?: true) }

      before do
        actual_scope = instance_double(Sequel::Dataset)
        allow(GoodsNomenclature).to receive(:actual).and_return(actual_scope)
        allow(actual_scope).to receive(:where).with(goods_nomenclature_item_id: '0101000000').and_return(actual_scope)
        allow(actual_scope).to receive(:first).and_return(declarable_commodity)
        allow(declarable_commodity).to receive(:declarable?).and_return(true)
      end

      it 'returns declarable goods for the specified nomenclature item id' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is MeasureComponent' do
      let(:change) { { type: 'MeasureComponent', measure_sid: 123 } }
      let(:measure_record) { { goods_nomenclature_item_id: '0101000000' } }
      let(:declarable_commodity) { instance_double(Commodity, goods_nomenclature_item_id: '0101000000', declarable?: true) }

      before do
        db_double = instance_double(Sequel::Database)
        measures_dataset = instance_double(Sequel::Dataset)
        allow(Sequel::Model).to receive(:db).and_return(db_double)
        allow(db_double).to receive(:[]).with(:measures).and_return(measures_dataset)
        allow(measures_dataset).to receive(:where).with(measure_sid: 123).and_return(instance_double(Sequel::Dataset, first: measure_record))

        actual_scope = instance_double(Sequel::Dataset)
        allow(GoodsNomenclature).to receive(:actual).and_return(actual_scope)
        allow(actual_scope).to receive(:where).with(goods_nomenclature_item_id: '0101000000').and_return(actual_scope)
        allow(actual_scope).to receive(:first).and_return(declarable_commodity)
        allow(declarable_commodity).to receive(:declarable?).and_return(true)
      end

      it 'finds measure and returns declarable goods for its commodity code' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is MeasureCondition' do
      let(:change) { { type: 'MeasureCondition', measure_sid: 123 } }
      let(:measure_record) { { goods_nomenclature_item_id: '0101000000' } }
      let(:declarable_commodity) { instance_double(Commodity, goods_nomenclature_item_id: '0101000000', declarable?: true) }

      before do
        db_double = instance_double(Sequel::Database)
        measures_dataset = instance_double(Sequel::Dataset)
        allow(Sequel::Model).to receive(:db).and_return(db_double)
        allow(db_double).to receive(:[]).with(:measures).and_return(measures_dataset)
        allow(measures_dataset).to receive(:where).with(measure_sid: 123).and_return(instance_double(Sequel::Dataset, first: measure_record))

        # Mock GoodsNomenclature lookup
        actual_scope = instance_double(Sequel::Dataset)
        allow(GoodsNomenclature).to receive(:actual).and_return(actual_scope)
        allow(actual_scope).to receive(:where).with(goods_nomenclature_item_id: '0101000000').and_return(actual_scope)
        allow(actual_scope).to receive(:first).and_return(declarable_commodity)
        allow(declarable_commodity).to receive(:declarable?).and_return(true)
      end

      it 'finds measure and returns declarable goods for its commodity code' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is GeographicalArea' do
      let(:change) { { type: 'GeographicalArea', geographical_area_id: 'GB' } }
      let(:measure_records) { [{ goods_nomenclature_item_id: '0101000000' }] }
      let(:declarable_commodity) { instance_double(Commodity, goods_nomenclature_item_id: '0101000000', declarable?: true) }

      before do
        db_double = instance_double(Sequel::Database)
        measures_dataset = instance_double(Sequel::Dataset)
        allow(Sequel::Model).to receive(:db).and_return(db_double)
        allow(db_double).to receive(:[]).with(:measures).and_return(measures_dataset)

        filtered_dataset = instance_double(Sequel::Dataset)
        allow(measures_dataset).to receive(:where).with(geographical_area_id: 'GB').and_return(filtered_dataset)
        allow(filtered_dataset).to receive(:where).with(operation_date: date).and_return(filtered_dataset)
        allow(filtered_dataset).to receive(:distinct).with(:goods_nomenclature_item_id).and_return(filtered_dataset)
        allow(filtered_dataset).to receive(:map).and_yield(measure_records.first).and_return([declarable_commodity])

        # Mock GoodsNomenclature lookup
        actual_scope = instance_double(Sequel::Dataset)
        allow(GoodsNomenclature).to receive(:actual).and_return(actual_scope)
        allow(actual_scope).to receive(:where).with(goods_nomenclature_item_id: '0101000000').and_return(actual_scope)
        allow(actual_scope).to receive(:first).and_return(declarable_commodity)
        allow(declarable_commodity).to receive(:declarable?).and_return(true)
      end

      it 'finds measures for geographical area and returns declarable goods' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is Certificate' do
      let(:change) { { type: 'Certificate', certificate_type_code: 'Y', certificate_code: '999' } }
      let(:condition_records) { [{ measure_sid: 123 }] }
      let(:measure_record) { { goods_nomenclature_item_id: '0101000000' } }
      let(:declarable_commodity) { instance_double(Commodity, goods_nomenclature_item_id: '0101000000', declarable?: true) }

      before do
        # Mock database queries
        db_double = instance_double(Sequel::Database)
        conditions_dataset = instance_double(Sequel::Dataset)
        measures_dataset = instance_double(Sequel::Dataset)

        allow(Sequel::Model).to receive(:db).and_return(db_double)
        allow(db_double).to receive(:[]).with(:measure_conditions).and_return(conditions_dataset)
        allow(db_double).to receive(:[]).with(:measures).and_return(measures_dataset)

        # Mock conditions lookup
        filtered_conditions = instance_double(Sequel::Dataset)
        allow(conditions_dataset).to receive(:where).with(certificate_type_code: 'Y').and_return(filtered_conditions)
        allow(filtered_conditions).to receive(:where).with(certificate_code: '999').and_return(filtered_conditions)
        allow(filtered_conditions).to receive(:distinct).with(:measure_sid).and_return(filtered_conditions)
        allow(filtered_conditions).to receive(:each).and_yield(condition_records.first)

        allow(measures_dataset).to receive(:where).with(measure_sid: 123).and_return(instance_double(Sequel::Dataset, first: measure_record))

        actual_scope = instance_double(Sequel::Dataset)
        allow(GoodsNomenclature).to receive(:actual).and_return(actual_scope)
        allow(actual_scope).to receive(:where).with(goods_nomenclature_item_id: '0101000000').and_return(actual_scope)
        allow(actual_scope).to receive(:first).and_return(declarable_commodity)
        allow(declarable_commodity).to receive(:declarable?).and_return(true)
      end

      it 'finds measures for certificate and returns declarable goods' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is AdditionalCode' do
      let(:change) { { type: 'AdditionalCode', additional_code_sid: '12345' } }
      let(:measure_records) { [{ goods_nomenclature_item_id: '0101000000' }] }
      let(:declarable_commodity) { instance_double(Commodity, goods_nomenclature_item_id: '0101000000', declarable?: true) }

      before do
        db_double = instance_double(Sequel::Database)
        measures_dataset = instance_double(Sequel::Dataset)
        allow(Sequel::Model).to receive(:db).and_return(db_double)
        allow(db_double).to receive(:[]).with(:measures).and_return(measures_dataset)

        filtered_dataset = instance_double(Sequel::Dataset)
        allow(measures_dataset).to receive(:where).with(additional_code_sid: '12345').and_return(filtered_dataset)
        allow(filtered_dataset).to receive(:where).with(operation_date: date).and_return(filtered_dataset)
        allow(filtered_dataset).to receive(:distinct).with(:goods_nomenclature_item_id).and_return(filtered_dataset)
        allow(filtered_dataset).to receive(:map).and_yield(measure_records.first).and_return([declarable_commodity])

        # Mock GoodsNomenclature lookup
        actual_scope = instance_double(Sequel::Dataset)
        allow(GoodsNomenclature).to receive(:actual).and_return(actual_scope)
        allow(actual_scope).to receive(:where).with(goods_nomenclature_item_id: '0101000000').and_return(actual_scope)
        allow(actual_scope).to receive(:first).and_return(declarable_commodity)
        allow(declarable_commodity).to receive(:declarable?).and_return(true)
      end

      it 'finds measures for additional code and returns declarable goods' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is unknown' do
      let(:change) { { type: 'Unknown' } }

      it 'returns empty array' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([])
      end
    end
  end

  describe '#find_declarable_goods_under_code' do
    let(:declarable_commodity) { instance_double(Commodity, goods_nomenclature_item_id: '0101000000', declarable?: true) }
    let(:non_declarable_commodity) { instance_double(Commodity, goods_nomenclature_item_id: '0102000000', declarable?: false) }
    let(:descendant_commodity) { instance_double(Commodity, goods_nomenclature_item_id: '0102100000', declarable?: true) }

    context 'when goods nomenclature is declarable' do
      before do
        actual_scope = instance_double(Sequel::Dataset)
        allow(GoodsNomenclature).to receive(:actual).and_return(actual_scope)
        allow(actual_scope).to receive(:where).with(goods_nomenclature_item_id: '0101000000').and_return(actual_scope)
        allow(actual_scope).to receive(:first).and_return(declarable_commodity)
        allow(declarable_commodity).to receive(:declarable?).and_return(true)
      end

      it 'returns the goods nomenclature itself' do
        result = service.send(:find_declarable_goods_under_code, declarable_commodity.goods_nomenclature_item_id)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when goods nomenclature is not declarable but has declarable descendants' do
      before do
        actual_scope = instance_double(Sequel::Dataset)
        allow(GoodsNomenclature).to receive(:actual).and_return(actual_scope)
        allow(actual_scope).to receive(:where).with(goods_nomenclature_item_id: '0102000000').and_return(actual_scope)
        allow(actual_scope).to receive(:first).and_return(non_declarable_commodity)
        allow(non_declarable_commodity).to receive_messages(
          declarable?: false,
          descendants: [descendant_commodity],
        )
      end

      it 'returns declarable descendants' do
        result = service.send(:find_declarable_goods_under_code, non_declarable_commodity.goods_nomenclature_item_id)
        expect(result).to eq([descendant_commodity])
      end
    end

    context 'when goods nomenclature item id is nil' do
      it 'returns empty array' do
        result = service.send(:find_declarable_goods_under_code, nil)
        expect(result).to eq([])
      end
    end

    context 'when goods nomenclature is not found' do
      before do
        actual_scope = instance_double(Sequel::Dataset)
        allow(GoodsNomenclature).to receive(:actual).and_return(actual_scope)
        allow(actual_scope).to receive(:where).with(goods_nomenclature_item_id: 'non_existent').and_return(actual_scope)
        allow(actual_scope).to receive(:first).and_return(nil)
      end

      it 'returns empty array' do
        result = service.send(:find_declarable_goods_under_code, 'non_existent')
        expect(result).to eq([])
      end
    end
  end

  describe '#find_declarable_goods_for_measure_association' do
    let(:measure_sid) { '12345' }
    let(:goods_nomenclature_item_id) { '0101000000' }
    let(:change) { { measure_sid: measure_sid } }
    let(:measure_record) { { goods_nomenclature_item_id: goods_nomenclature_item_id } }
    let(:declarable_goods) { [instance_double(Commodity, goods_nomenclature_item_id: '0101000000')] }

    before do
      db_double = instance_double(Sequel::Database)
      measures_dataset = instance_double(Sequel::Dataset)
      allow(Sequel::Model).to receive(:db).and_return(db_double)
      allow(db_double).to receive(:[]).with(:measures).and_return(measures_dataset)
      allow(measures_dataset).to receive(:where).with(measure_sid: measure_sid).and_return(instance_double(Sequel::Dataset, first: measure_record))

      actual_scope = instance_double(Sequel::Dataset)
      allow(GoodsNomenclature).to receive(:actual).and_return(actual_scope)
      allow(actual_scope).to receive(:where).with(goods_nomenclature_item_id: goods_nomenclature_item_id).and_return(actual_scope)
      allow(actual_scope).to receive(:first).and_return(declarable_goods.first)
      allow(declarable_goods.first).to receive(:declarable?).and_return(true)
    end

    it 'finds measure and returns declarable goods for its commodity code' do
      result = service.send(:find_declarable_goods_for_measure_association, change)
      expect(result).to eq(declarable_goods)
    end

    context 'when measure is not found' do
      let(:measure_record) { nil }

      it 'returns empty array' do
        result = service.send(:find_declarable_goods_for_measure_association, change)
        expect(result).to eq([])
      end
    end
  end

  describe '#find_declarable_goods_for_additional_code' do
    let(:additional_code_sid) { '12345' }
    let(:change) { { additional_code_sid: additional_code_sid } }
    let(:measure_records) { [{ goods_nomenclature_item_id: '0101000000' }, { goods_nomenclature_item_id: '0102000000' }] }
    let(:declarable_commodity1) { instance_double(Commodity, goods_nomenclature_item_id: '0101000000', declarable?: true) }
    let(:declarable_commodity2) { instance_double(Commodity, goods_nomenclature_item_id: '0102000000', declarable?: true) }

    before do
      db_double = instance_double(Sequel::Database)
      measures_dataset = instance_double(Sequel::Dataset)
      allow(Sequel::Model).to receive(:db).and_return(db_double)
      allow(db_double).to receive(:[]).with(:measures).and_return(measures_dataset)

      filtered_dataset = instance_double(Sequel::Dataset)
      allow(measures_dataset).to receive(:where).with(additional_code_sid: additional_code_sid).and_return(filtered_dataset)
      allow(filtered_dataset).to receive(:where).with(operation_date: date).and_return(filtered_dataset)
      allow(filtered_dataset).to receive(:distinct).with(:goods_nomenclature_item_id).and_return(filtered_dataset)
      allow(filtered_dataset).to receive(:map).and_yield(measure_records[0]).and_yield(measure_records[1]).and_return([[declarable_commodity1], [declarable_commodity2]])

      # Mock GoodsNomenclature lookups
      actual_scope = instance_double(Sequel::Dataset)
      allow(GoodsNomenclature).to receive(:actual).and_return(actual_scope)

      allow(actual_scope).to receive(:where).with(goods_nomenclature_item_id: '0101000000').and_return(instance_double(Sequel::Dataset, first: declarable_commodity1))
      allow(actual_scope).to receive(:where).with(goods_nomenclature_item_id: '0102000000').and_return(instance_double(Sequel::Dataset, first: declarable_commodity2))

      allow(declarable_commodity1).to receive(:declarable?).and_return(true)
      allow(declarable_commodity2).to receive(:declarable?).and_return(true)
    end

    it 'finds measures for additional code and returns unique declarable goods' do
      result = service.send(:find_declarable_goods_for_additional_code, change)
      expect(result).to eq([declarable_commodity1, declarable_commodity2])
    end

    context 'when there are duplicate goods nomenclature item ids' do
      let(:measure_records) { [{ goods_nomenclature_item_id: '0101000000' }, { goods_nomenclature_item_id: '0101000000' }] }

      before do
        filtered_dataset = instance_double(Sequel::Dataset)
        allow(Sequel::Model.db[:measures]).to receive(:where).with(additional_code_sid: additional_code_sid).and_return(filtered_dataset)
        allow(filtered_dataset).to receive(:where).with(operation_date: date).and_return(filtered_dataset)
        allow(filtered_dataset).to receive(:distinct).with(:goods_nomenclature_item_id).and_return(filtered_dataset)
        allow(filtered_dataset).to receive(:map).and_yield(measure_records[0]).and_yield(measure_records[1]).and_return([[declarable_commodity1], [declarable_commodity1]])
      end

      it 'returns unique declarable goods' do
        result = service.send(:find_declarable_goods_for_additional_code, change)
        expect(result).to eq([declarable_commodity1])
      end
    end
  end
end

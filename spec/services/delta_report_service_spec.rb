RSpec.describe DeltaReportService do
  subject(:service) { described_class.new(date, date) }

  let(:date) { Date.parse('2024-08-11') }

  def create_test_commodity(item_id:, sid:, declarable: true, description: 'Test commodity')
    commodity = instance_double(Commodity,
                                goods_nomenclature_item_id: item_id,
                                goods_nomenclature_sid: sid,
                                declarable?: declarable,
                                chapter_short_code: item_id[0..1])
    # rubocop:disable RSpec/VerifiedDoubles
    description_double = double('GoodsNomenclatureDescription', description: description)
    # rubocop:enable RSpec/VerifiedDoubles
    allow(commodity).to receive(:goods_nomenclature_description).and_return(description_double)
    commodity
  end

  def mock_goods_nomenclature_lookup(commodity, commodity_code = nil)
    commodity_code ||= commodity.goods_nomenclature_item_id
    scope = instance_double(Sequel::Dataset)

    allow(GoodsNomenclature).to receive(:where).with(goods_nomenclature_item_id: commodity_code).and_return(scope)

    goods_nomenclature = instance_double(GoodsNomenclature,
                                         goods_nomenclature_sid: commodity.goods_nomenclature_sid)
    allow(scope).to receive(:first).and_return(goods_nomenclature)

    sid_scope = instance_double(Sequel::Dataset)
    allow(GoodsNomenclature).to receive(:where).with(goods_nomenclature_sid: commodity.goods_nomenclature_sid).and_return(sid_scope)
    allow(sid_scope).to receive(:first).and_return(commodity)

    allow(commodity).to receive(:descendants).and_return([])
  end

  def mock_goods_nomenclature_lookup_by_sid(sid, goods_nomenclature)
    dataset = instance_double(Sequel::Dataset, first: goods_nomenclature)
    allow(GoodsNomenclature).to receive(:where).with(goods_nomenclature_sid: sid).and_return(dataset)
  end

  def mock_goods_nomenclature_lookup_by_item_id(item_id, goods_nomenclature)
    dataset = instance_double(Sequel::Dataset, first: goods_nomenclature)
    allow(GoodsNomenclature).to receive(:where).with(goods_nomenclature_item_id: item_id).and_return(dataset)
  end

  def mock_measure_lookup(measure_sid, measure_record)
    dataset = mock_database_query(:measures)
    allow(dataset).to receive(:where).with(measure_sid: measure_sid).and_return(instance_double(Sequel::Dataset, first: measure_record))
  end

  def mock_database_query(table_name)
    db_double = instance_double(Sequel::Database)
    dataset = instance_double(Sequel::Dataset)
    allow(Sequel::Model).to receive(:db).and_return(db_double)
    allow(db_double).to receive(:[]).with(table_name).and_return(dataset)
    dataset
  end

  def mock_filtered_dataset(dataset, filters)
    filtered_dataset = dataset
    filters.each do |filter_method, filter_args|
      new_dataset = instance_double(Sequel::Dataset)
      if filter_args.is_a?(Array)
        allow(filtered_dataset).to receive(filter_method).with(*filter_args).and_return(new_dataset)
      else
        allow(filtered_dataset).to receive(filter_method).with(filter_args).and_return(new_dataset)
      end
      filtered_dataset = new_dataset
    end
    filtered_dataset
  end

  describe '.generate' do
    subject(:result) { described_class.generate(start_date: date) }

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
      expect(service.start_date).to eq(date)
      expect(service.end_date).to eq(date)
    end

    it 'initializes changes as empty hash' do
      expect(service.instance_variable_get(:@changes)).to eq({})
    end
  end

  describe '#generate_report' do
    subject(:result) { service.generate_report }

    let(:commodity) { create_test_commodity(item_id: '0101000000', sid: 100) }
    let(:mock_changes) do
      {
        goods_nomenclatures: [
          {
            type: 'GoodsNomenclature',
            goods_nomenclature_sid: commodity.goods_nomenclature_sid,
            description: 'Commodity added',
            date_of_effect: date,
            change: 'new',
          },
        ],
        measures: [],
        measure_components: [],
        measure_conditions: [],
        excluded_geographical_areas: [],
        geographical_areas: [],
        certificates: [],
        additional_codes: [],
        footnotes: [],
      }
    end

    let(:expected_commodity_change) do
      {
        type: 'GoodsNomenclature',
        operation_date: date,
        chapter: commodity.chapter_short_code,
        commodity_code: commodity.goods_nomenclature_item_id,
        commodity_code_description: commodity.goods_nomenclature_description.description,
        import_export: 'n/a',
        geo_area: 'n/a',
        measure_type: 'n/a',
        type_of_change: 'Commodity added',
        date_of_effect: date,
        change: 'new',
        ott_url: "https://www.trade-tariff.service.gov.uk/commodities/#{commodity.goods_nomenclature_item_id}?day=#{date.day}&month=#{date.month}&year=#{date.year}",
        api_url: "https://www.trade-tariff.service.gov.uk/uk/api/commodities/#{commodity.goods_nomenclature_item_id}",
      }
    end

    before do
      allow(DeltaReportService::CommodityChanges).to receive(:collect).with(date).and_return(mock_changes[:goods_nomenclatures])
      allow(DeltaReportService::MeasureChanges).to receive(:collect).with(date).and_return(mock_changes[:measures])
      allow(DeltaReportService::MeasureComponentChanges).to receive(:collect).with(date).and_return(mock_changes[:measure_components])
      allow(DeltaReportService::MeasureConditionChanges).to receive(:collect).with(date).and_return(mock_changes[:measure_conditions])
      allow(DeltaReportService::ExcludedGeographicalAreaChanges).to receive(:collect).with(date).and_return(mock_changes[:excluded_geographical_areas])
      allow(DeltaReportService::GeographicalAreaChanges).to receive(:collect).with(date).and_return(mock_changes[:geographical_areas])
      allow(DeltaReportService::CertificateChanges).to receive(:collect).with(date).and_return(mock_changes[:certificates])
      allow(DeltaReportService::AdditionalCodeChanges).to receive(:collect).with(date).and_return(mock_changes[:additional_codes])
      allow(DeltaReportService::FootnoteChanges).to receive(:collect).with(date).and_return(mock_changes[:footnotes])
      allow(DeltaReportService::FootnoteAssociationMeasureChanges).to receive(:collect).with(date).and_return(mock_changes[:footnote_association_measures] || [])
      allow(DeltaReportService::FootnoteAssociationGoodsNomenclatureChanges).to receive(:collect).with(date).and_return(mock_changes[:footnote_association_goods_nomenclature] || [])
      allow(DeltaReportService::ExcelGenerator).to receive(:call).and_return(instance_double(Axlsx::Package))
      allow(TimeMachine).to receive(:at).and_yield

      mock_goods_nomenclature_lookup(commodity)
    end

    it 'wraps the execution in TimeMachine block' do
      result
      expect(TimeMachine).to have_received(:at).with(date).once
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
      expect(DeltaReportService::FootnoteChanges).to have_received(:collect).with(date)
      expect(DeltaReportService::FootnoteAssociationMeasureChanges).to have_received(:collect).with(date)
      expect(DeltaReportService::FootnoteAssociationGoodsNomenclatureChanges).to have_received(:collect).with(date)
    end

    it 'calls ExcelGenerator with commodity change records and date' do
      result
      expect(DeltaReportService::ExcelGenerator).to have_received(:call).with([[expected_commodity_change]], '2024_08_11')
    end

    it 'returns the expected report structure' do
      expect(result).to include(
        dates: '2024_08_11',
        total_records: 1,
        commodity_changes: [expected_commodity_change],
      )
    end

    context 'when there are footnote changes' do
      let(:footnote) { instance_double(Footnote, measures: nil, goods_nomenclatures: nil) }
      let(:measure_object) { instance_double(Measure, goods_nomenclature_item_id: '0202000000') }
      let(:footnote_commodity) { create_test_commodity(item_id: '0202000000', sid: 200, description: 'Meat commodity') }

      let(:mock_changes) do
        {
          goods_nomenclatures: [],
          measures: [],
          measure_components: [],
          measure_conditions: [],
          excluded_geographical_areas: [],
          geographical_areas: [],
          certificates: [],
          additional_codes: [],
          footnotes: [
            {
              type: 'Footnote',
              footnote_oid: '12345',
              description: 'Footnote description',
              date_of_effect: date,
              change: 'TN001: Product specific footnote',
            },
          ],
        }
      end

      let(:expected_footnote_change) do
        {
          type: 'Footnote',
          operation_date: date,
          chapter: footnote_commodity.chapter_short_code,
          commodity_code: footnote_commodity.goods_nomenclature_item_id,
          commodity_code_description: footnote_commodity.goods_nomenclature_description.description,
          import_export: 'n/a',
          geo_area: 'n/a',
          measure_type: 'n/a',
          type_of_change: 'Footnote description',
          date_of_effect: date,
          change: 'TN001: Product specific footnote',
          ott_url: "https://www.trade-tariff.service.gov.uk/commodities/#{footnote_commodity.goods_nomenclature_item_id}?day=#{date.day}&month=#{date.month}&year=#{date.year}",
          api_url: "https://www.trade-tariff.service.gov.uk/uk/api/commodities/#{footnote_commodity.goods_nomenclature_item_id}",
        }
      end

      before do
        allow(Footnote).to receive(:[]).with(oid: '12345').and_return(footnote)
        allow(footnote).to receive_messages(measures: [measure_object], goods_nomenclatures: nil)

        mock_goods_nomenclature_lookup(footnote_commodity, '0202000000')
      end

      it 'generates commodity changes for footnotes' do
        expect(result[:commodity_changes].flatten).to include(expected_footnote_change)
        expect(result[:total_records]).to eq(1)
      end
    end

    context 'when there are footnote association measure changes' do
      let(:mock_changes) do
        {
          goods_nomenclatures: [],
          measures: [],
          measure_components: [],
          measure_conditions: [],
          excluded_geographical_areas: [],
          geographical_areas: [],
          certificates: [],
          additional_codes: [],
          footnotes: [],
          footnote_association_measures: [
            {
              type: 'FootnoteAssociationMeasure',
              measure_sid: '12345',
              measure_type: '103: Import duty',
              import_export: 'Import',
              geo_area: 'GB: United Kingdom',
              additional_code: '1234: Additional code description',
              description: 'Footnote TN001 updated',
              date_of_effect: date,
              change: nil,
            },
          ],
          footnote_association_goods_nomenclature: [],
        }
      end

      let(:measure_record) { { goods_nomenclature_item_id: '0303000000' } }
      let(:measure_commodity) { create_test_commodity(item_id: '0303000000', sid: 300, description: 'Fish commodity') }

      let(:expected_footnote_association_measure_change) do
        {
          type: 'FootnoteAssociationMeasure',
          operation_date: date,
          chapter: measure_commodity.chapter_short_code,
          commodity_code: measure_commodity.goods_nomenclature_item_id,
          commodity_code_description: measure_commodity.goods_nomenclature_description.description,
          import_export: 'Import',
          geo_area: 'GB: United Kingdom',
          measure_type: '103: Import duty',
          type_of_change: 'Footnote TN001 updated',
          date_of_effect: date,
          change: nil,
          ott_url: "https://www.trade-tariff.service.gov.uk/commodities/#{measure_commodity.goods_nomenclature_item_id}?day=#{date.day}&month=#{date.month}&year=#{date.year}",
          api_url: "https://www.trade-tariff.service.gov.uk/uk/api/commodities/#{measure_commodity.goods_nomenclature_item_id}",
        }
      end

      before do
        mock_measure_lookup('12345', measure_record)
        mock_goods_nomenclature_lookup(measure_commodity, '0303000000')
      end

      it 'generates commodity changes for footnote association measure changes' do
        expect(result[:commodity_changes].flatten).to include(expected_footnote_association_measure_change)
        expect(result[:total_records]).to eq(1)
      end
    end

    context 'when there are footnote association goods nomenclature changes' do
      let(:goods_nomenclature_commodity) { create_test_commodity(item_id: '0404000000', sid: 400, description: 'Dairy commodity') }

      let(:mock_changes) do
        {
          goods_nomenclatures: [],
          measures: [],
          measure_components: [],
          measure_conditions: [],
          excluded_geographical_areas: [],
          geographical_areas: [],
          certificates: [],
          additional_codes: [],
          footnotes: [],
          footnote_association_measures: [],
          footnote_association_goods_nomenclature: [
            {
              type: 'FootnoteAssociationGoodsNomenclature',
              goods_nomenclature_sid: 400,
              description: 'Footnote CD001 updated for goods nomenclature',
              date_of_effect: date,
              change: 'footnote association updated',
            },
          ],
        }
      end

      let(:expected_footnote_association_goods_nomenclature_change) do
        {
          type: 'FootnoteAssociationGoodsNomenclature',
          operation_date: date,
          chapter: goods_nomenclature_commodity.chapter_short_code,
          commodity_code: goods_nomenclature_commodity.goods_nomenclature_item_id,
          commodity_code_description: goods_nomenclature_commodity.goods_nomenclature_description.description,
          import_export: 'n/a',
          geo_area: 'n/a',
          measure_type: 'n/a',
          type_of_change: 'Footnote CD001 updated for goods nomenclature',
          date_of_effect: date,
          change: 'footnote association updated',
          ott_url: "https://www.trade-tariff.service.gov.uk/commodities/#{goods_nomenclature_commodity.goods_nomenclature_item_id}?day=#{date.day}&month=#{date.month}&year=#{date.year}",
          api_url: "https://www.trade-tariff.service.gov.uk/uk/api/commodities/#{goods_nomenclature_commodity.goods_nomenclature_item_id}",
        }
      end

      before do
        mock_goods_nomenclature_lookup(goods_nomenclature_commodity, '0404000000')
      end

      it 'generates commodity changes for footnote association goods nomenclature changes' do
        expect(result[:commodity_changes].flatten).to include(expected_footnote_association_goods_nomenclature_change)
        expect(result[:total_records]).to eq(1)
      end
    end

    context 'when there are no changes' do
      let(:mock_changes) do
        {
          goods_nomenclatures: [],
          measures: [],
          measure_components: [],
          measure_conditions: [],
          excluded_geographical_areas: [],
          geographical_areas: [],
          certificates: [],
          additional_codes: [],
          footnotes: [],
          footnote_association_measures: [],
          footnote_association_goods_nomenclature: [],
        }
      end

      it 'returns empty commodity changes' do
        expect(result[:commodity_changes].flatten).to be_empty
        expect(result[:total_records]).to eq(0)
      end
    end
  end

  describe '#find_affected_declarable_goods' do
    context 'when change type is Measure' do
      let(:change) { { type: 'Measure', goods_nomenclature_item_id: '0101000000' } }
      let(:declarable_commodity) { create_test_commodity(item_id: '0101000000', sid: 100) }

      before do
        mock_goods_nomenclature_lookup(declarable_commodity)
      end

      it 'returns declarable goods for the specified nomenclature item id' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is GoodsNomenclature' do
      let(:change) { { type: 'GoodsNomenclature', goods_nomenclature_sid: 123 } }
      let(:declarable_commodity) { create_test_commodity(item_id: '0101000000', sid: 123) }

      before do
        mock_goods_nomenclature_lookup_by_sid(declarable_commodity.goods_nomenclature_sid, declarable_commodity)
      end

      it 'returns declarable goods for the specified nomenclature item id' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is MeasureComponent' do
      let(:change) { { type: 'MeasureComponent', measure_sid: 123 } }
      let(:measure_record) { { goods_nomenclature_item_id: '0101000000' } }
      let(:declarable_commodity) { create_test_commodity(item_id: '0101000000', sid: 100) }

      before do
        mock_measure_lookup(123, measure_record)
        mock_goods_nomenclature_lookup(declarable_commodity)
      end

      it 'finds measure and returns declarable goods for its commodity code' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is MeasureCondition' do
      let(:change) { { type: 'MeasureCondition', measure_sid: 123 } }
      let(:measure_record) { { goods_nomenclature_item_id: '0101000000' } }
      let(:declarable_commodity) { create_test_commodity(item_id: '0101000000', sid: 100) }

      before do
        mock_measure_lookup(123, measure_record)
        mock_goods_nomenclature_lookup(declarable_commodity)
      end

      it 'finds measure and returns declarable goods for its commodity code' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is ExcludedGeographicalArea' do
      let(:change) { { type: 'ExcludedGeographicalArea', measure_sid: 123 } }
      let(:measure_record) { { goods_nomenclature_item_id: '0101000000' } }
      let(:declarable_commodity) { create_test_commodity(item_id: '0101000000', sid: 100) }

      before do
        mock_measure_lookup(123, measure_record)
        mock_goods_nomenclature_lookup(declarable_commodity)
      end

      it 'finds measure and returns declarable goods for its commodity code' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is FootnoteAssociationMeasure' do
      let(:change) { { type: 'FootnoteAssociationMeasure', measure_sid: 123 } }
      let(:measure_record) { { goods_nomenclature_item_id: '0101000000' } }
      let(:declarable_commodity) { create_test_commodity(item_id: '0101000000', sid: 100) }

      before do
        mock_measure_lookup(123, measure_record)
        mock_goods_nomenclature_lookup(declarable_commodity)
      end

      it 'finds measure and returns declarable goods for its commodity code' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is FootnoteAssociationGoodsNomenclature' do
      let(:change) { { type: 'FootnoteAssociationGoodsNomenclature', goods_nomenclature_sid: 100 } }
      let(:declarable_commodity) { create_test_commodity(item_id: '0101000000', sid: 100) }

      before do
        mock_goods_nomenclature_lookup(declarable_commodity)
      end

      it 'returns declarable goods for the specified nomenclature item id' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is GeographicalArea' do
      let(:change) { { type: 'GeographicalArea', geographical_area_sid: 123 } }
      let(:measure_records) { [{ goods_nomenclature_item_id: '0101000000' }] }
      let(:declarable_commodity) { create_test_commodity(item_id: '0101000000', sid: 100) }

      before do
        service.instance_variable_set(:@date, date)
        measures_dataset = mock_database_query(:measures)
        filtered_dataset = mock_filtered_dataset(measures_dataset, [
          [:where, { geographical_area_sid: 123 }],
          [:where, { operation_date: date }],
          %i[distinct goods_nomenclature_item_id],
        ])
        allow(filtered_dataset).to receive(:map).and_yield(measure_records.first).and_return([declarable_commodity])

        mock_goods_nomenclature_lookup(declarable_commodity)
      end

      it 'finds measures for geographical area and returns declarable goods' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is Certificate' do
      let(:change) { { type: 'Certificate', certificate_type_code: 'Y', certificate_code: '999' } }
      let(:condition_records) { [{ measure_sid: 123, operation_date: Date.parse('2024-08-10') }] }
      let(:measure_record) { { goods_nomenclature_item_id: '0101000000' } }
      let(:declarable_commodity) { create_test_commodity(item_id: '0101000000', sid: 100) }

      before do
        db_double = instance_double(Sequel::Database)
        conditions_dataset = instance_double(Sequel::Dataset)
        measures_dataset = instance_double(Sequel::Dataset)
        measure_dataset = instance_double(Sequel::Dataset)
        measure = build(:measure, goods_nomenclature_item_id: '0101000000')

        allow(Sequel::Model).to receive(:db).and_return(db_double)
        allow(db_double).to receive(:[]).with(:measure_conditions_oplog).and_return(conditions_dataset)
        allow(db_double).to receive(:[]).with(:measures).and_return(measures_dataset)

        filtered_conditions = mock_filtered_dataset(conditions_dataset, [
          [:where, { certificate_type_code: 'Y' }],
          [:where, { certificate_code: '999' }],
          %i[distinct measure_sid],
        ])
        allow(filtered_conditions).to receive(:each).and_yield(condition_records.first)

        allow(Measure).to receive(:where).with(measure_sid: 123).and_return(measure_dataset)
        allow(measure_dataset).to receive(:first).and_return(measure)

        mock_goods_nomenclature_lookup(declarable_commodity)
      end

      it 'finds measures for certificate and returns declarable goods' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is AdditionalCode' do
      let(:change) { { type: 'AdditionalCode', additional_code_sid: '12345' } }
      let(:measure_records) { [{ goods_nomenclature_item_id: '0101000000' }] }
      let(:declarable_commodity) { create_test_commodity(item_id: '0101000000', sid: 100) }

      before do
        service.instance_variable_set(:@date, date)
        measures_dataset = mock_database_query(:measures)
        filtered_dataset = mock_filtered_dataset(measures_dataset, [
          [:where, { additional_code_sid: '12345' }],
          [:where, { operation_date: date }],
          %i[distinct goods_nomenclature_item_id],
        ])
        allow(filtered_dataset).to receive(:map).and_yield(measure_records.first).and_return([declarable_commodity])

        mock_goods_nomenclature_lookup(declarable_commodity)
      end

      it 'finds measures for additional code and returns declarable goods' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is Footnote and footnote has measures' do
      let(:change) { { type: 'Footnote', footnote_oid: '12345' } }
      let(:footnote) { instance_double(Footnote) }
      let(:measure_objects) { [instance_double(Measure, goods_nomenclature_item_id: '0101000000')] }
      let(:declarable_commodity) { create_test_commodity(item_id: '0101000000', sid: 100) }

      before do
        allow(Footnote).to receive(:[]).with(oid: '12345').and_return(footnote)
        allow(footnote).to receive(:measures).and_return(measure_objects)
        mock_goods_nomenclature_lookup(declarable_commodity)
      end

      it 'finds measures for footnote and returns declarable goods' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is Footnote and footnote has goods nomenclatures' do
      let(:change) { { type: 'Footnote', footnote_oid: '12345' } }
      let(:footnote) { instance_double(Footnote) }
      let(:goods_nomenclature_records) { [instance_double(GoodsNomenclature, goods_nomenclature_item_id: '0101000000')] }
      let(:declarable_commodity) { create_test_commodity(item_id: '0101000000', sid: 100) }

      before do
        allow(Footnote).to receive(:[]).with(oid: '12345').and_return(footnote)
        allow(footnote).to receive_messages(measures: nil, goods_nomenclatures: goods_nomenclature_records)
        mock_goods_nomenclature_lookup(declarable_commodity)
      end

      it 'finds goods nomenclatures for footnote and returns declarable goods' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when change type is Footnote and footnote has no associations' do
      let(:change) { { type: 'Footnote', footnote_oid: '12345' } }
      let(:footnote) { instance_double(Footnote) }

      before do
        allow(Footnote).to receive(:[]).with(oid: '12345').and_return(footnote)
        allow(footnote).to receive_messages(measures: nil, goods_nomenclatures: nil)
      end

      it 'returns empty array when footnote has no associations' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([])
      end
    end

    context 'when change type is Footnote and footnote is not found' do
      let(:change) { { type: 'Footnote', footnote_oid: '99999' } }

      before do
        allow(Footnote).to receive(:[]).with(oid: '99999').and_return(nil)
      end

      it 'returns empty array when footnote is not found' do
        result = service.send(:find_affected_declarable_goods, change)
        expect(result).to eq([])
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
    let(:declarable_commodity) { create_test_commodity(item_id: '0101000000', sid: 100) }
    let(:non_declarable_commodity) { create_test_commodity(item_id: '0102000000', sid: 102, declarable: false) }
    let(:descendant_commodity) { create_test_commodity(item_id: '0102100000', sid: 103) }

    context 'when goods nomenclature is declarable' do
      before do
        mock_goods_nomenclature_lookup(declarable_commodity)
      end

      it 'returns the goods nomenclature itself' do
        result = service.send(:find_declarable_goods_under_code, declarable_commodity.goods_nomenclature_item_id)
        expect(result).to eq([declarable_commodity])
      end
    end

    context 'when goods nomenclature is not declarable but has declarable descendants' do
      before do
        scope = instance_double(Sequel::Dataset)
        allow(GoodsNomenclature).to receive(:where).with(goods_nomenclature_item_id: '0102000000').and_return(scope)
        allow(scope).to receive(:first).and_return(non_declarable_commodity)

        scope_by_sid = instance_double(Sequel::Dataset)
        allow(GoodsNomenclature).to receive(:where).with(goods_nomenclature_sid: 102).and_return(scope_by_sid)
        allow(scope_by_sid).to receive(:first).and_return(non_declarable_commodity)

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
    let(:declarable_goods) { [create_test_commodity(item_id: '0101000000', sid: 100)] }

    before do
      mock_measure_lookup(measure_sid, measure_record)
      mock_goods_nomenclature_lookup(declarable_goods.first)
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
    let(:declarable_commodity1) { create_test_commodity(item_id: '0101000000', sid: 100) }
    let(:declarable_commodity2) { create_test_commodity(item_id: '0102000000', sid: 101) }

    before do
      service.instance_variable_set(:@date, date)
      measures_dataset = mock_database_query(:measures)
      filtered_dataset = mock_filtered_dataset(measures_dataset, [
        [:where, { additional_code_sid: additional_code_sid }],
        [:where, { operation_date: date }],
        %i[distinct goods_nomenclature_item_id],
      ])
      allow(filtered_dataset).to receive(:map).and_yield(measure_records[0]).and_yield(measure_records[1]).and_return([[declarable_commodity1], [declarable_commodity2]])

      mock_goods_nomenclature_lookup(declarable_commodity1, '0101000000')
      mock_goods_nomenclature_lookup(declarable_commodity2, '0102000000')
    end

    it 'finds measures for additional code and returns unique declarable goods' do
      result = service.send(:find_declarable_goods_for_additional_code, change)
      expect(result).to eq([declarable_commodity1, declarable_commodity2])
    end

    context 'when there are duplicate goods nomenclature item ids' do
      let(:measure_records) { [{ goods_nomenclature_item_id: '0101000000' }, { goods_nomenclature_item_id: '0101000000' }] }

      before do
        service.instance_variable_set(:@date, date)
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

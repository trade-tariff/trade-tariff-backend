RSpec.describe DeltaReportService do
  subject(:service) { described_class.new(date, date) }

  let(:date) { Date.parse('2024-08-11') }

  before do
    # rubocop:disable RSpec/VerifiedDoubles
    operation_klass_double = double(Class)
    allow(operation_klass_double).to receive(:where).and_return(double('dataset', none?: true, any?: false))
    # rubocop:enable RSpec/VerifiedDoubles
    allow(Measure).to receive(:operation_klass).and_return(operation_klass_double)
  end

  def create_test_commodity(item_id:, sid:, declarable: true, description: 'Test commodity')
    commodity = instance_double(Commodity,
                                goods_nomenclature_item_id: item_id,
                                goods_nomenclature_sid: sid,
                                declarable?: declarable,
                                validity_start_date: Time.zone.today,
                                chapter_short_code: item_id[0..1])
    # rubocop:disable RSpec/VerifiedDoubles
    description_double = double('GoodsNomenclatureDescription',
                                description: description,
                                csv_formatted_description: description)
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
      allow(TradeTariffBackend).to receive(:xi?).and_return(false)
      allow(ReportsMailer).to receive(:delta).and_return(double(deliver_now: true)) # rubocop:disable RSpec/VerifiedDoubles
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
        package: instance_double(Axlsx::Package),
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
        quota_events: [],
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
      allow(DeltaReportService::CommodityDescriptionChanges).to receive(:collect).with(date).and_return(mock_changes[:goods_nomenclature_descriptions] || [])
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
      allow(DeltaReportService::QuotaEventChanges).to receive(:collect).with(date).and_return(mock_changes[:quota_events] || [])
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
      expect(DeltaReportService::QuotaEventChanges).to have_received(:collect).with(date)
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
          quota_events: [],
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
              measure_type: 'Import duty',
              import_export: 'Import',
              geo_area: 'United Kingdom (GB)',
              additional_code: '1234: Additional code description',
              description: 'Footnote TN001 updated',
              date_of_effect: date,
              change: nil,
            },
          ],
          footnote_association_goods_nomenclature: [],
          quota_events: [],
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
          geo_area: 'United Kingdom (GB)',
          measure_type: 'Import duty',
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
          quota_events: [],
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

    context 'when there are quota event changes' do
      let(:quota_definition) { create_test_commodity(item_id: '0505000000', sid: 500, description: 'Quota commodity') }

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
          quota_events: [
            {
              type: 'QuotaEvent',
              quota_definition_sid: 500,
              description: 'Quota Status: Exhausted',
              date_of_effect: date,
              change: 'Quota Exhausted',
            },
          ],
        }
      end

      let(:expected_quota_event_change) do
        {
          type: 'QuotaEvent',
          operation_date: date,
          chapter: quota_definition.chapter_short_code,
          commodity_code: quota_definition.goods_nomenclature_item_id,
          commodity_code_description: quota_definition.goods_nomenclature_description.description,
          import_export: 'Import',
          geo_area: 'United Kingdom (GB)',
          measure_type: 'Third country duty',
          type_of_change: 'Quota Status: Exhausted',
          date_of_effect: date,
          change: 'Quota Exhausted',
          ott_url: "https://www.trade-tariff.service.gov.uk/commodities/#{quota_definition.goods_nomenclature_item_id}?day=#{date.day}&month=#{date.month}&year=#{date.year}",
          api_url: "https://www.trade-tariff.service.gov.uk/uk/api/commodities/#{quota_definition.goods_nomenclature_item_id}",
        }
      end

      before do
        quota_def_record = instance_double(QuotaDefinition,
                                           quota_definition_sid: 500,
                                           quota_order_number_id: '050001',
                                           balance: 100,
                                           measurement_unit: 'kg')
        allow(QuotaDefinition).to receive(:first).with(quota_definition_sid: 500).and_return(quota_def_record)

        measure = instance_double(Measure, goods_nomenclature_item_id: '0505000000')
        geographical_area = instance_double(GeographicalArea)
        allow(quota_def_record).to receive(:measures).and_return([measure])
        allow(measure).to receive_messages(
          geographical_area: geographical_area,
          excluded_geographical_areas: [],
        )
        # rubocop:disable RSpec/SubjectStub
        allow(service).to receive(:measure_type).with(measure).and_return('Third country duty')
        allow(service).to receive(:import_export).with(measure).and_return('Import')
        allow(service).to receive(:geo_area).with(geographical_area, []).and_return('United Kingdom (GB)')
        # rubocop:enable RSpec/SubjectStub

        mock_goods_nomenclature_lookup(quota_definition, '0505000000')
      end

      it 'generates commodity changes for quota events' do
        expect(result[:commodity_changes].flatten).to include(expected_quota_event_change)
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
          quota_events: [],
        }
      end

      it 'returns empty commodity changes and zero total records' do
        expect(result).to include(
          dates: '2024_08_11',
          total_records: 0,
          commodity_changes: [],
        )
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

        measures_dataset = instance_double(Sequel::Dataset)
        allow(Sequel::Model.db).to receive(:[]).with(:measures).and_return(measures_dataset)

        after_where = instance_double(Sequel::Dataset)
        allow(measures_dataset).to receive(:where).with(geographical_area_sid: 123).and_return(after_where)

        after_distinct = instance_double(Sequel::Dataset)
        allow(after_where).to receive(:distinct).with(:goods_nomenclature_item_id).and_return(after_distinct)

        allow(after_distinct).to receive(:select_map).with([:goods_nomenclature_item_id]).and_return(%w[0101000000])

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
        db_double = Sequel::Model.db
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

        measures_dataset = instance_double(Sequel::Dataset)
        allow(Sequel::Model.db).to receive(:[]).with(:measures).and_return(measures_dataset)

        after_where = instance_double(Sequel::Dataset)
        allow(measures_dataset).to receive(:where).with(additional_code_sid: '12345').and_return(after_where)

        after_distinct = instance_double(Sequel::Dataset)
        allow(after_where).to receive(:distinct).with(:goods_nomenclature_item_id).and_return(after_distinct)

        allow(after_distinct).to receive(:select_map).with([:goods_nomenclature_item_id]).and_return(%w[0101000000])

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

    context 'when change type is QuotaEvent' do
      let(:change) { { type: 'QuotaEvent', quota_definition_sid: 123 } }
      let(:quota_definition) { instance_double(QuotaDefinition, quota_order_number_id: '050001', balance: 100, measurement_unit: 'kg') }
      let(:measure) { instance_double(Measure, goods_nomenclature_item_id: '0505000000') }
      let(:measures) { [measure] }
      let(:geographical_area) { instance_double(GeographicalArea) }
      let(:declarable_commodity) { create_test_commodity(item_id: '0505000000', sid: 100) }

      before do
        allow(QuotaDefinition).to receive(:first).with(quota_definition_sid: 123).and_return(quota_definition)
        allow(quota_definition).to receive(:measures).and_return(measures)
        allow(measure).to receive_messages(
          geographical_area: geographical_area,
          excluded_geographical_areas: [],
        )
        # rubocop:disable RSpec/SubjectStub
        allow(service).to receive(:measure_type).with(measure).and_return('Third country duty')
        allow(service).to receive(:import_export).with(measure).and_return('Import')
        allow(service).to receive(:geo_area).with(geographical_area, []).and_return('United Kingdom (GB)')
        # rubocop:enable RSpec/SubjectStub
        mock_goods_nomenclature_lookup(declarable_commodity, '0505000000')
      end

      it 'finds quota definition and order number to get commodity code' do
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

        allow(descendant_commodity).to receive(:declarable?).and_return(true)
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

      measures_dataset = instance_double(Sequel::Dataset)
      allow(Sequel::Model.db).to receive(:[]).with(:measures).and_return(measures_dataset)

      after_where = instance_double(Sequel::Dataset)
      allow(measures_dataset).to receive(:where).with(additional_code_sid: additional_code_sid).and_return(after_where)

      after_distinct = instance_double(Sequel::Dataset)
      allow(after_where).to receive(:distinct).with(:goods_nomenclature_item_id).and_return(after_distinct)

      allow(after_distinct).to receive(:select_map).with([:goods_nomenclature_item_id]).and_return(%w[0101000000 0102000000])

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

        measures_dataset = instance_double(Sequel::Dataset)
        allow(Sequel::Model.db).to receive(:[]).with(:measures).and_return(measures_dataset)

        after_where = instance_double(Sequel::Dataset)
        allow(measures_dataset).to receive(:where).with(additional_code_sid: additional_code_sid).and_return(after_where)

        after_distinct = instance_double(Sequel::Dataset)
        allow(after_where).to receive(:distinct).with(:goods_nomenclature_item_id).and_return(after_distinct)

        allow(after_distinct).to receive(:select_map).with([:goods_nomenclature_item_id]).and_return(%w[0101000000 0101000000])

        mock_goods_nomenclature_lookup(declarable_commodity1, '0101000000')
      end

      it 'returns unique declarable goods' do
        result = service.send(:find_declarable_goods_for_additional_code, change)
        expect(result).to eq([declarable_commodity1])
      end
    end
  end

  describe 'caching functionality' do
    let(:declarable_commodity) { create_test_commodity(item_id: '0101000000', sid: 100) }

    describe '#find_declarable_goods_under_code caching' do
      context 'when result is cached' do
        before do
          service.instance_variable_get(:@cache)[:declarable_goods]['item_0101000000'] = [declarable_commodity]
          allow(GoodsNomenclature).to receive(:where)
        end

        it 'returns cached result without database query' do
          result = service.send(:find_declarable_goods_under_code, '0101000000')
          expect(result).to eq([declarable_commodity])
          expect(GoodsNomenclature).not_to have_received(:where)
        end
      end
    end

    describe '#find_declarable_goods_for_sid caching' do
      context 'when result is cached' do
        before do
          service.instance_variable_get(:@cache)[:declarable_goods]['sid_100'] = [declarable_commodity]
          allow(GoodsNomenclature).to receive(:where)
        end

        it 'returns cached result without database query' do
          result = service.send(:find_declarable_goods_for_sid, 100)
          expect(result).to eq([declarable_commodity])
          expect(GoodsNomenclature).not_to have_received(:where)
        end
      end
    end

    describe 'cache clearing' do
      before do
        # Populate cache
        service.instance_variable_get(:@cache)[:declarable_goods]['sid_100'] = [declarable_commodity]
        service.instance_variable_get(:@cache)[:declarable_goods]['item_0101000000'] = [declarable_commodity]
      end

      it 'clears all caches when clear_cache is called' do
        expect(service.instance_variable_get(:@cache)[:declarable_goods]).not_to be_empty

        service.send(:clear_cache)

        expect(service.instance_variable_get(:@cache)[:declarable_goods]).to be_empty
      end
    end
  end
end

RSpec.describe CdsImporter::ExcelWriter::Measure do
  subject(:mapper) { described_class.new(models) }

  let(:measure) do
    instance_double(
      Measure,
      class: instance_double(Class, name: 'Measure'),
      operation: 'C',
      goods_nomenclature_item_id: '0101210000',
      additional_code_type_id: 'X',
      additional_code_id: '999',
      measure_type_id: 'ATT',
      geographical_area_sid: 1,
      ordernumber: '123456',
      validity_start_date: Date.new(2025, 1, 1),
      validity_end_date: Date.new(2025, 12, 31),
      measure_sid: 111,
    )
  end

  let(:measure2) do
    instance_double(
      Measure,
      class: instance_double(Class, name: 'Measure'),
      operation: 'C',
      goods_nomenclature_item_id: '0101210000',
      additional_code_type_id: 'X',
      additional_code_id: '999',
      measure_type_id: '112',
      geographical_area_sid: 2,
      ordernumber: '123456',
      validity_start_date: nil,
      validity_end_date: nil,
      measure_sid: 111,
    )
  end

  let(:measure_component) do
    instance_double(
      MeasureComponent,
      class: instance_double(Class, name: 'MeasureComponent'),
      operation: 'C',
      duty_expression_id: '01',
      duty_amount: 5.5,
      monetary_unit_code: '',
      measurement_unit_code: '',
      measurement_unit_qualifier_code: '',
    )
  end

  let(:excluded_geo_area) do
    instance_double(
      MeasureExcludedGeographicalArea,
      class: instance_double(Class, name: 'MeasureExcludedGeographicalArea'),
      operation: 'C',
      excluded_geographical_area: 'EU',
    )
  end

  let(:footnote) do
    instance_double(
      FootnoteAssociationMeasure,
      class: instance_double(Class, name: 'FootnoteAssociationMeasure'),
      operation: 'C',
      footnote_type_id: 'X',
      footnote_id: '123',
    )
  end

  let(:condition) do
    instance_double(
      MeasureCondition,
      class: instance_double(Class, name: 'MeasureCondition'),
      operation: 'C',
      certificate_type_code: 'A',
      certificate_code: '001',
      condition_code: '10',
      action_code: '01',
    )
  end

  let(:condition2) do
    instance_double(
      MeasureCondition,
      class: instance_double(Class, name: 'MeasureCondition'),
      operation: 'C',
      certificate_type_code: 'A',
      certificate_code: '001',
      condition_code: '20',
      action_code: '02',
    )
  end

  let(:models) do
    [measure, measure_component, excluded_geo_area, footnote, condition]
  end
  let(:geographical_area) { create(:geographical_area, :with_description, geographical_area_sid: 1) }

  before do
    create(:measure_type, measure_type_id: 'ATT', measure_type_description: 'Supplementary amount')
    geographical_area
    create(:measure_condition_code, :with_description, condition_code: '10', description: 'Condition Desc')
    create(:measure_action, :with_description, action_code: '01')
    create(:measurement_unit, :with_description, measurement_unit_code: 'KGM', description: 'kilogram')
  end

  describe '#data_row' do
    it 'returns a fully formatted row' do
      row = mapper.data_row

      expect(row[0]).to eq('Create a new measure')
      expect(row[1]).to eq('0101210000')
      expect(row[2]).to eq('X999')
      expect(row[3]).to eq('ATT(Supplementary amount)')
      expect(row[4]).to eq("#{geographical_area.geographical_area_id}(#{geographical_area.description})")
      expect(row[5]).to eq('123456')
      expect(row[6]).to eq('01/01/2025')
      expect(row[7]).to eq('31/12/2025')
      expect(row[8]).to include('5.5000%')
      expect(row[9]).to eq('EU')
      expect(row[10]).to eq('X123')
      expect(row[11]).to include("Certificate: A001, Condition code: 10 (Condition Desc), Action code: 01 (Import/export not allowed after control)\n")
      expect(row[12]).to eq(111)
    end

    context 'when descriptions not found' do
      let(:models) do
        [measure2, measure_component, excluded_geo_area, footnote, condition2]
      end

      it 'returns just the id' do
        row = mapper.data_row

        expect(row[3]).to eq('112')
        expect(row[4]).to eq('2')
        expect(row[11]).to include('Certificate: A001')
      end
    end

    context 'when conditions are deleted' do
      let(:condition) do
        instance_double(
          MeasureCondition,
          class: instance_double(Class, name: 'MeasureCondition'),
          operation: 'D',
        )
      end

      it 'omits them from the string' do
        expect(mapper.data_row[11]).to eq('')
      end
    end

    context 'when footnotes are deleted' do
      let(:footnote) do
        instance_double(
          FootnoteAssociationMeasure,
          class: instance_double(Class, name: 'FootnoteAssociationMeasure'),
          operation: 'D',
        )
      end

      it 'omits them from the string' do
        expect(mapper.data_row[10]).to eq('')
      end
    end

    context 'when excluded areas are deleted' do
      let(:excluded_geo_area) do
        instance_double(
          MeasureExcludedGeographicalArea,
          class: instance_double(Class, name: 'MeasureExcludedGeographicalArea'),
          operation: 'D',
        )
      end

      it 'omits them from the string' do
        expect(mapper.data_row[9]).to eq('')
      end
    end
  end

  describe '#duty_string' do
    def comp(attrs = {})
      {
        class: instance_double(Class, name: 'MeasureComponent'),
        operation: 'C',
        duty_expression_id: '01',
        duty_amount: 5.5,
        monetary_unit_code: '',
        measurement_unit_code: '',
        measurement_unit_qualifier_code: '',
      }.merge(attrs)
       .then { |h| instance_double(MeasureComponent, h) }
    end

    it 'formats percent when monetary_unit_code is empty' do
      c = comp(duty_expression_id: '01', duty_amount: 5.5, monetary_unit_code: '')
      expect(mapper.send(:duty_string, c)).to eq('5.5000%')
    end

    it 'formats monetary unit with measurement unit and qualifier' do
      c = comp(
        duty_expression_id: '01',
        duty_amount: 5.5,
        monetary_unit_code: 'GBP',
        measurement_unit_code: 'KGM',
        measurement_unit_qualifier_code: 'E',
      )

      expect(mapper.send(:duty_string, c)).to eq('5.5000 GBP / kilogram / net drained wt')
    end

    it "adds prefix '+ ' for expressions 04,19,20" do
      %w[04 19 20].each do |expr|
        c = comp(duty_expression_id: expr, duty_amount: 3.0, monetary_unit_code: '')
        expect(mapper.send(:duty_string, c)).to eq('+ 3.0000%')
      end
    end

    it "adds 'MIN ' and 'MAX ' prefixes for 15 and 17,35 respectively" do
      min_c = comp(duty_expression_id: '15', duty_amount: 2.25, monetary_unit_code: '')
      expect(mapper.send(:duty_string, min_c)).to eq('MIN 2.2500%')

      %w[17 35].each do |expr|
        max_c = comp(duty_expression_id: expr, duty_amount: 4.0, monetary_unit_code: '')
        expect(mapper.send(:duty_string, max_c)).to eq('MAX 4.0000%')
      end
    end

    it 'returns measurement_unit_code for duty expression 99' do
      c = comp(duty_expression_id: '99', measurement_unit_code: 'KGM')
      expect(mapper.send(:duty_string, c)).to eq('KGM')
    end

    it 'returns empty string for unexpected duty_expression_id' do
      c = comp(duty_expression_id: 'ZZ')
      expect(mapper.send(:duty_string, c)).to eq('')
    end
  end
end

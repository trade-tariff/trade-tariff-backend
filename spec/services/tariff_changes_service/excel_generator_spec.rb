RSpec.describe TariffChangesService::ExcelGenerator do
  let(:date) { '2024-08-11' }
  let(:change_records) do
    [
      {
        import_export: 'Import',
        geo_area: 'United Kingdom',
        measure_type: 'Third country duty',
        additional_code: 'N/A',
        chapter: '01',
        commodity_code: '0101000000',
        commodity_code_description: 'Live horses, asses, mules and hinnies',
        type_of_change: 'Added',
        change_detail: 'New measure added',
        date_of_effect: '2024-08-11',
        ott_url: 'https://www.trade-tariff.service.gov.uk/commodities/0101000000',
        api_url: 'https://www.trade-tariff.service.gov.uk/api/v2/commodities/0101000000',
      },
      {
        import_export: 'Export',
        geo_area: 'European Union',
        measure_type: 'Export licence',
        additional_code: '1AAA: Export permit',
        chapter: '02',
        commodity_code: '0202000000',
        commodity_code_description: 'Meat of bovine animals, frozen',
        type_of_change: 'Updated',
        change_detail: 'Rate changed from 5% to 7%',
        date_of_effect: '2024-08-12',
        ott_url: 'https://www.trade-tariff.service.gov.uk/commodities/0202000000',
        api_url: 'https://www.trade-tariff.service.gov.uk/api/v2/commodities/0202000000',
      },
    ]
  end

  describe '.call' do
    context 'when change_records is empty' do
      it 'returns nil' do
        result = described_class.call([], date)
        expect(result).to be_nil
      end
    end

    context 'when change_records has data' do
      it 'creates a new instance and calls #call' do
        instance = instance_double(described_class, call: 'workbook')
        allow(described_class).to receive(:new).and_return(instance)
        result = described_class.call(change_records, date)
        expect(result).to eq('workbook')
      end
    end
  end

  describe '#initialize' do
    let(:generator) { described_class.new(change_records, date) }

    it 'sets change_records' do
      expect(generator.change_records).to eq(change_records)
    end

    it 'sets date' do
      expect(generator.date).to eq(date)
    end
  end

  describe '#call' do
    let(:generator) { described_class.new(change_records, date) }
    let(:workbook) { generator.call }
    let(:worksheet) { workbook.get_worksheet_by_name('Commodity watch list') }

    before do
      allow(Rails.env).to receive(:development?).and_return(false)
    end

    it 'creates a FastExcel workbook' do
      expect(workbook).to be_a(Libxlsxwriter::Workbook)
    end
  end

  describe '#excel_header_row' do
    let(:generator) { described_class.new(change_records, date) }

    it 'returns the correct header array' do
      expected_headers = [
        'Import/Export (if applicable)',
        'Impacted Geographical area (if applicable)',
        'Impacted Measure (if applicable)',
        'Additional Code (if applicable)',
        'Chapter',
        'Commodity Code',
        'Commodity Code description',
        'Change Type',
        'Change Detail',
        'Change Date of Effect',
        'View OTT for Change Date of Effect',
        'API call for the changed Commodity',
      ]
      expect(generator.send(:excel_header_row)).to eq(expected_headers)
    end

    it 'has 12 columns' do
      expect(generator.send(:excel_header_row).size).to eq(12)
    end
  end

  describe '#excel_column_widths' do
    let(:generator) { described_class.new(change_records, date) }

    it 'returns the correct column widths' do
      expected_widths = [20, 30, 30, 30, 15, 20, 50, 30, 30, 22, 80, 60]
      expect(generator.send(:excel_column_widths)).to eq(expected_widths)
    end

    it 'has widths for all 12 columns' do
      expect(generator.send(:excel_column_widths).size).to eq(12)
    end
  end

  describe '#build_excel_row' do
    let(:generator) { described_class.new(change_records, date) }
    let(:record) { change_records.first }

    it 'builds a row array from a record hash' do
      row = generator.send(:build_excel_row, record)

      expect(row).to eq([
        'Import',
        'United Kingdom',
        'Third country duty',
        'N/A',
        '01',
        '0101000000',
        'Live horses, asses, mules and hinnies',
        'Added',
        'New measure added',
        '2024-08-11',
        'https://www.trade-tariff.service.gov.uk/commodities/0101000000',
        'https://www.trade-tariff.service.gov.uk/api/v2/commodities/0101000000',
      ])
    end

    it 'formats date correctly' do
      row = generator.send(:build_excel_row, record)
      expect(row[9]).to eq('2024-08-11')
    end

    it 'handles nil date' do
      record_with_nil_date = record.merge(date_of_effect: nil)
      row = generator.send(:build_excel_row, record_with_nil_date)
      expect(row[9]).to be_nil
    end

    it 'returns an array with 12 elements' do
      row = generator.send(:build_excel_row, record)
      expect(row.size).to eq(12)
    end
  end
end

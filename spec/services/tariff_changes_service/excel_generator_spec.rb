RSpec.describe TariffChangesService::ExcelGenerator do
  let(:date) { '2024-08-11' }
  let(:change_records) do
    [
      {
        import_export: 'Import',
        geo_area: 'United Kingdom',
        measure_type: 'Third country duty',
        additional_code: 'N/A',
        quota_order_number: 'N/A',
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
        quota_order_number: '055001',
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
        expect(described_class.call([], date)).to be_nil
      end
    end

    it 'returns a FastExcel workbook' do
      expect(described_class.call(change_records, date)).to be_a(Libxlsxwriter::Workbook)
    end
  end

  describe '#call' do
    let(:workbook) { described_class.new(change_records, date).call }
    let(:xlsx_data) { workbook.read_string }

    it 'renders the expected worksheet rows' do
      expect(worksheet_row_texts(xlsx_data)).to include(
        ['Changes to your commodity watch list'],
        ["Published #{date}"],
        [
          'Import/Export (if applicable)',
          'Impacted Geographical area (if applicable)',
          'Impacted Measure (if applicable)',
          'Additional Code (if applicable)',
          'Quota order number (if applicable)',
          'Chapter',
          'Commodity Code',
          'Commodity Code description',
          'Change Type',
          'Change Detail',
          'Change Date of Effect',
          'View OTT for Change Date of Effect',
          'API call for the changed Commodity',
        ],
        [
          'Import',
          'United Kingdom',
          'Third country duty',
          'N/A',
          'N/A',
          '01',
          '0101000000',
          'Live horses, asses, mules and hinnies',
          'Added',
          'New measure added',
          '2024-08-11',
          'https://www.trade-tariff.service.gov.uk/commodities/0101000000',
          'https://www.trade-tariff.service.gov.uk/api/v2/commodities/0101000000',
        ],
      )
    end

    it 'adds hyperlinks for OTT and API columns' do
      relationships_xml = worksheet_relationships_xml(xlsx_data)

      expect(relationships_xml).to include(change_records[0][:ott_url])
      expect(relationships_xml).to include(change_records[0][:api_url])
      expect(relationships_xml).to include(change_records[1][:ott_url])
      expect(relationships_xml).to include(change_records[1][:api_url])
    end

    it 'sets expected column widths and filters' do
      xml = worksheet_xml(xlsx_data)

      expect(xml).to include('width="20.7109375"')
      expect(xml).to include('<mergeCell ref="A4:E4"/>')
      expect(xml).to include('<mergeCell ref="F4:H4"/>')
      expect(xml).to include('<mergeCell ref="I4:K4"/>')
      expect(xml).to include('<mergeCell ref="L4:M4"/>')
      expect(table_xml(xlsx_data)).to include('ref="A5:M7"')
      expect(table_xml(xlsx_data)).to include('name="TableStyleMedium2"')
      expect(table_xml(xlsx_data)).to include('showRowStripes="1"')
    end

    it 'preserves the explicit blank spacer cell emitted by the caxlsx report' do
      expect(worksheet_xml(xlsx_data)).to include('<c r="A3"')
    end
  end

  describe '#build_excel_row' do
    let(:generator) { described_class.new(change_records, date) }

    it 'builds a row array from a record hash' do
      row = generator.send(:build_excel_row, change_records.first)

      expect(row[0..10]).to eq([
        'Import',
        'United Kingdom',
        'Third country duty',
        'N/A',
        'N/A',
        '01',
        '0101000000',
        'Live horses, asses, mules and hinnies',
        'Added',
        'New measure added',
        '2024-08-11',
      ])
      expect(row[11]).to be_a(FastExcel::URL)
      expect(row[12]).to be_a(FastExcel::URL)
    end

    context 'when the date of effect is a Date' do
      before do
        change_records.first[:date_of_effect] = Date.new(2024, 8, 11)
      end

      it 'serializes the date as the same ISO string as the caxlsx report' do
        row = generator.send(:build_excel_row, change_records.first)

        expect(row[10]).to eq('2024-08-11')
      end
    end
  end
end

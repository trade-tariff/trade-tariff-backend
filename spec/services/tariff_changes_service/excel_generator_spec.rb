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
        instance = instance_double(described_class, call: 'package')
        allow(described_class).to receive(:new).and_return(instance)
        result = described_class.call(change_records, date)
        expect(result).to eq('package')
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
    let(:package) { generator.call }
    let(:workbook) { package.workbook }
    let(:worksheet) { workbook.worksheets.first }

    before do
      allow(Rails.env).to receive(:development?).and_return(false)
    end

    it 'creates an Axlsx package' do
      expect(package).to be_a(Axlsx::Package)
    end

    it 'uses shared strings' do
      expect(package.use_shared_strings).to be true
    end

    it 'creates a worksheet named "Commodity Watchlist"' do
      expect(worksheet.name).to eq('Commodity Watchlist')
    end

    it 'sets default row height' do
      expect(worksheet.sheet_format_pr.default_row_height).to eq(40.0)
      expect(worksheet.sheet_format_pr.custom_height).to be false
    end

    describe 'worksheet structure' do
      it 'has the correct number of rows' do
        # 5 header rows + 2 data rows
        expect(worksheet.rows.size).to eq(7)
      end

      it 'sets the title row correctly' do
        title_row = worksheet.rows[0]
        expect(title_row.cells[0].value).to eq('Changes to your Commodity Watchlist')
        expect(title_row.height).to eq(40)
      end

      it 'sets the subtitle row correctly' do
        subtitle_row = worksheet.rows[1]
        expect(subtitle_row.cells[0].value).to eq("Published #{date}")
        expect(subtitle_row.height).to eq(25)
      end

      it 'has an empty row' do
        empty_row = worksheet.rows[2]
        expect(empty_row.cells[0].value).to eq('')
        expect(empty_row.height).to eq(20)
      end

      it 'sets the pre-header row correctly' do
        pre_header_row = worksheet.rows[3]
        expect(pre_header_row.cells[0].value).to eq('Is this change relevant to your business (useful filters)')
        expect(pre_header_row.height).to eq(40)
      end

      it 'sets the header row correctly' do
        header_row = worksheet.rows[4]
        expect(header_row.cells[0].value).to eq("Import/Export\n(if applicable)")
        expect(header_row.height).to eq(60)
      end
    end

    describe 'cell merging' do
      it 'merges the pre-header cells correctly' do
        merged_cells = worksheet.instance_variable_get(:@merged_cells)
        expect(merged_cells).to include('A4:D4', 'E4:G4', 'H4:J4', 'K4:L4')
      end
    end

    describe 'auto filter' do
      it 'sets auto filter on header row' do
        expect(worksheet.auto_filter.range).to eq('A5:J5')
      end
    end

    describe 'frozen panes' do
      let(:pane) { worksheet.sheet_view.pane }

      it 'freezes the header rows' do
        expect(pane.top_left_cell).to eq('A6')
        expect(pane.state).to eq('frozen')
        expect(pane.y_split).to eq(5)
      end
    end

    describe 'data rows' do
      it 'adds data rows for each record' do
        data_rows = worksheet.rows[5..]
        expect(data_rows.size).to eq(2)
      end

      it 'populates data correctly' do
        first_data_row = worksheet.rows[5]
        expect(first_data_row.cells[0].value).to eq('Import')
        expect(first_data_row.cells[5].value).to eq('0101000000')
        expect(first_data_row.cells[7].value).to eq('Added')
      end

      it 'applies alternating row styles' do
        first_row_styles = worksheet.rows[5].cells.map(&:style)
        second_row_styles = worksheet.rows[6].cells.map(&:style)
        expect(first_row_styles).not_to eq(second_row_styles)
      end
    end

    describe 'column widths' do
      it 'sets column widths correctly' do
        expected_widths = [20, 30, 30, 30, 15, 20, 50, 30, 30, 22, 80, 60]
        expect(worksheet.column_info.map(&:width)).to eq(expected_widths)
      end
    end
  end

  describe '#excel_header_row' do
    let(:generator) { described_class.new(change_records, date) }

    it 'returns the correct header array' do
      expected_headers = [
        "Import/Export\n(if applicable)",
        "Impacted Geographical area\n(if applicable)",
        "Impacted Measure\n(if applicable)",
        "Additional Code\n(if applicable)",
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

  describe '#excel_autofilter_range' do
    let(:generator) { described_class.new(change_records, date) }

    it 'returns the correct range for auto filter' do
      expect(generator.send(:excel_autofilter_range)).to eq('A5:J5')
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

  describe '#cell_styles' do
    let(:generator) { described_class.new(change_records, date) }

    before do
      generator.instance_variable_set(:@workbook, Axlsx::Package.new.workbook)
    end

    context 'without background color' do
      let(:styles) { generator.send(:cell_styles) }

      it 'returns a hash of styles' do
        expect(styles).to be_a(Hash)
        expect(styles.keys).to include(:pre_header, :header, :date, :commodity_code, :chapter, :text, :center_text, :bold_text)
      end

      it 'creates Axlsx styles' do
        expect(styles[:text]).to be_a(Integer)
      end
    end

    context 'with background color' do
      let(:styles) { generator.send(:cell_styles, 'F8F9FA') }

      it 'applies background color to styles' do
        expect(styles).to be_a(Hash)
      end
    end
  end

  describe '#build_row_styles' do
    let(:generator) { described_class.new(change_records, date) }
    let(:styles) { generator.send(:build_row_styles, is_even_row: true) }

    before do
      generator.instance_variable_set(:@workbook, Axlsx::Package.new.workbook)
    end

    it 'returns an array of 12 styles' do
      expect(styles.size).to eq(12)
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

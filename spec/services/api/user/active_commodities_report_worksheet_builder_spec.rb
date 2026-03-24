RSpec.describe Api::User::ActiveCommoditiesReportWorksheetBuilder do
  describe '.call' do
    subject(:build_worksheet) { described_class.call(workbook:, report_rows:) }

    let(:package) { Axlsx::Package.new }
    let(:worksheet) do
      build_worksheet
      workbook.worksheets.first
    end
    let(:workbook) { package.workbook }

    let(:report_rows) do
      [
        {
          code: '1111111111',
          chapter: '11: Chapter eleven',
          description: {
            plain_description: 'Expired commodity description',
            hierarchy_levels: ['Expired commodity description'],
            has_heading: false,
          },
          status: Api::User::ActiveCommoditiesReportService::EXPIRED,
        },
        {
          code: '2222222222',
          chapter: '22: Chapter twenty two',
          description: {
            plain_description: 'Active commodity description',
            hierarchy_levels: ['Active commodity description'],
            has_heading: false,
          },
          status: Api::User::ActiveCommoditiesReportService::ACTIVE,
        },
        {
          code: '3333333333',
          chapter: 'Not applicable',
          description: { plain_description: 'ignored for invalid row' },
          status: Api::User::ActiveCommoditiesReportService::ERROR_FROM_UPLOAD,
        },
      ]
    end

    it 'creates a worksheet with the expected name' do
      expect(worksheet.name).to eq(described_class::SHEET_NAME)
    end

    it 'renders the title row with an inline date' do
      freeze_time do
        expected_date = Time.zone.today.strftime('%d/%m/%Y')

        expect(worksheet.rows[0].cells[0].value).to eq("Your commodities (#{expected_date})")
        expect(worksheet.rows[0].height).to eq(described_class::TITLE_ROW_HEIGHT)
      end
    end

    it 'renders instructions as rich text with bold ending sentence' do
      instructions_cell = worksheet.rows[2].cells[0].value

      expect(instructions_cell).to be_a(Axlsx::RichText)
      expect(instructions_cell.map(&:value).join).to include('Updating your commodity watch list:')
      expect(instructions_cell.map(&:value).join).to include('Ensure all codes are listed in column A.')
      expect(instructions_cell.last).to have_attributes(b: true)
      expect(worksheet.rows[2].height).to eq(described_class::INSTRUCTIONS_ROW_HEIGHT)
    end

    it 'applies intro merge layout and leaves upload row unmerged' do
      merged_cells = worksheet.instance_variable_get(:@merged_cells)

      expect(merged_cells).to include('A1:D1', 'A2:D2', 'A3:D3', 'A5:D5')
      expect(merged_cells).not_to include('A4:D4')
    end

    it 'applies blank row heights to both spacer rows' do
      expect(worksheet.rows[1].height).to eq(described_class::BLANK_ROW_HEIGHT)
      expect(worksheet.rows[4].height).to eq(described_class::BLANK_ROW_HEIGHT)
    end

    it 'adds upload hyperlink at A4' do
      expect(worksheet.hyperlinks.map(&:location)).to include(
        described_class::REPLACE_ALL_COMMODITIES_UPLOAD_URL,
      )
      expect(worksheet.hyperlinks.map(&:ref)).to include('A4')
    end

    it 'adds expected table headers and data rows' do
      header_row = worksheet.rows[5]
      expect(header_row.cells.map(&:value)).to eq(described_class::HEADERS)

      data_rows = worksheet.rows[6..].map do |row|
        [
          row.cells[0].value.to_s,
          extract_cell_text(row.cells[1].value),
          extract_cell_text(row.cells[2].value),
          row.cells[3].value.to_s,
        ]
      end

      expect(data_rows).to eq([
        ["1111111111\n ", '11: Chapter eleven', "Expired commodity description\n", 'Expired'],
        ["2222222222\n ", '22: Chapter twenty two', "Active commodity description\n", 'Active'],
        ["3333333333\n ", 'Not applicable', 'Not applicable', 'Error from upload'],
      ])
    end

    it 'adds a table over the populated data range' do
      table = worksheet.tables.first

      expect(table).not_to be_nil
      expect(table.ref).to eq('A6:D9')
    end

    context 'when there are no report rows' do
      let(:report_rows) { [] }

      it 'does not add a table' do
        expect(worksheet.tables).to be_empty
      end
    end
  end

  def extract_cell_text(value)
    return value.to_s unless value.is_a?(Axlsx::RichText)

    value.map(&:value).join
  end
end

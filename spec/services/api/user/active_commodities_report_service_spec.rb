RSpec.describe Api::User::ActiveCommoditiesReportService do
  let(:active_codes) { Set.new(%w[2222222222]) }
  let(:expired_codes) { Set.new(%w[1111111111]) }
  let(:invalid_codes) { Set.new(%w[3333333333]) }

  before do
    create(
      :commodity,
      :expired,
      :with_description,
      goods_nomenclature_item_id: '1111111111',
      goods_nomenclature_sid: 111,
      description: 'Expired commodity description',
    )

    create(
      :commodity,
      :actual,
      :with_description,
      goods_nomenclature_item_id: '2222222222',
      goods_nomenclature_sid: 222,
      description: 'Active commodity<br>description',
    )
  end

  describe '.call' do
    it 'delegates to an instance call' do
      instance = instance_double(described_class, call: :package)
      allow(described_class).to receive(:new).and_return(instance)

      result = described_class.call(active_codes, expired_codes, invalid_codes)

      expect(result).to eq(:package)
    end
  end

  describe '#call' do
    subject(:package) { described_class.new(active_codes, expired_codes, invalid_codes).call }

    let(:worksheet) { package.workbook.worksheets.first }

    it 'returns an Axlsx package' do
      expect(package).to be_a(Axlsx::Package)
    end

    it 'creates a worksheet named Your commodities' do
      expect(worksheet.name).to eq('Your commodities')
    end

    it 'adds a large title row before the table' do
      expect(worksheet.rows[0].cells[0].value).to eq('Your commodities')
    end

    it 'adds the instructions row before the table' do
      instructions_row = worksheet.rows[1].cells.map(&:value)

      expect(instructions_row[0]).to eq('Instructions:')
      expect(instructions_row[1]).to eq(
        "All your active and expired codes, as well as errors are listed on this spreadsheet.\n\nYou can edit, add and remove codes from this spreadsheet.\n\nThis spreadsheet is designed with the codes in column A, so you can upload it to update your commodity watch list.",
      )
    end

    it 'adds the date downloaded row in dd/mm/yyyy format' do
      freeze_time do
        dated_package = described_class.new(active_codes, expired_codes, invalid_codes).call
        dated_sheet = dated_package.workbook.worksheets.first

        date_row = dated_sheet.rows[2].cells.map(&:value)
        expect(date_row[0]).to eq('Date downloaded:')
        expect(date_row[1]).to eq(Time.zone.today.strftime('%d/%m/%Y'))
      end
    end

    it 'adds a replace all upload link row before the table' do
      link_row = worksheet.rows[4]

      expect(link_row.cells[0].value).to eq('Replace all commodities (upload)')
      expect(worksheet.hyperlinks.map(&:location)).to include(
        Api::User::ActiveCommoditiesReportService::REPLACE_ALL_COMMODITIES_UPLOAD_URL,
      )
      expect(worksheet.hyperlinks.map(&:ref)).to include('A5')
    end

    it 'adds the expected header row' do
      headers = worksheet.rows[6].cells.map(&:value)
      expect(headers).to eq(%w[Commodity Description Status])
    end

    it 'adds rows ordered by commodity code with status and description' do
      data_rows = worksheet.rows[7..].map do |row|
        [
          row.cells[0].value.to_s,
          extract_cell_text(row.cells[1].value),
          row.cells[2].value.to_s,
        ]
      end

      expect(data_rows).to eq([
        ["1111111111\n ", 'Expired commodity description', 'Expired'],
        ["2222222222\n ", "Active commodity\ndescription", 'Active'],
        ["3333333333\n ", 'Not applicable', 'Error from upload'],
      ])
    end

    it 'uses bold styling for values in the first table column' do
      first_data_cell = worksheet.rows[7].cells[0]
      font = package.workbook.styles.fonts[package.workbook.styles.cellXfs[first_data_cell.style].fontId]

      expect(font.b).to be true
    end

    it 'renders description values as plain text' do
      description_cell = worksheet.rows[7].cells[1]

      expect(description_cell.value).to be_a(String)
    end

    it 'enables table built-in row striping' do
      table = worksheet.tables.first
      style_info = table.respond_to?(:table_style_info) ? table.table_style_info : nil

      expect(style_info).not_to be_nil
      expect(style_info.show_row_stripes).to be true
    end

    it 'does not force a fixed explicit row height for table rows' do
      data_rows = worksheet.rows[7..9]
      expect(data_rows.map(&:height)).to all(be_nil)
    end

    it 'applies requested status colors and bold 12pt text' do
      styles = package.workbook.styles
      status_cells = worksheet.rows[7..9].map { |row| row.cells[2] }

      style_data = status_cells.map do |cell|
        xf = styles.cellXfs[cell.style]
        fill_xml = styles.fills[xf.fillId].to_xml_string
        font = styles.fonts[xf.fontId]

        {
          fill_xml: fill_xml,
          bold: font.b,
          size: font.sz.to_i,
        }
      end

      expect(style_data[0][:fill_xml]).to include('FFFFEE80')
      expect(style_data[1][:fill_xml]).to include('FFCFE4DC')
      expect(style_data[2][:fill_xml]).to include('FFF4D7D7')
      expect(style_data).to all(include(bold: true, size: 12))
    end

    it 'adds table styling for the full data range' do
      table = worksheet.tables.first

      expect(table).not_to be_nil
      expect(table.ref).to eq('A7:C10')
    end
  end

  def extract_cell_text(value)
    return value.to_s unless value.is_a?(Axlsx::RichText)

    value.map(&:value).join
  end
end

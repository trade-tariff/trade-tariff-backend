RSpec.describe Api::User::ActiveCommoditiesReportService do
  let(:active_codes) { Set.new(%w[2222222222]) }
  let(:expired_codes) { Set.new(%w[1111111111]) }
  let(:invalid_codes) { Set.new(%w[3333333333]) }

  before do
    create(
      :chapter,
      :with_description,
      goods_nomenclature_item_id: '1100000000',
      goods_nomenclature_sid: 11,
      description: 'Chapter Eleven',
    )

    create(
      :chapter,
      :with_description,
      goods_nomenclature_item_id: '2200000000',
      goods_nomenclature_sid: 22,
      description: 'Chapter Twenty Two',
    )

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

    let(:builder_class) { Api::User::ActiveCommoditiesReportWorksheetBuilder }
    let(:worksheet) { package.workbook.worksheets.first }

    it 'creates a worksheet named Your commodities' do
      expect(worksheet.name).to eq('Your commodities')
    end

    it 'adds a large title row before the table' do
      freeze_time do
        dated_package = described_class.new(active_codes, expired_codes, invalid_codes).call
        dated_sheet = dated_package.workbook.worksheets.first
        expected_date = Time.zone.today.strftime('%d/%m/%Y')

        expect(dated_sheet.rows[0].cells[0].value).to eq('Your commodities')
        expect(dated_sheet.rows[0].cells[1].value).to eq("(#{expected_date})")
        expect(dated_sheet.rows[0].height).to eq(builder_class::TITLE_ROW_HEIGHT)
      end
    end

    it 'adds the instructions rows before the table' do
      merged_cells = Array(worksheet.instance_variable_get(:@merged_cells))
      final_instruction = worksheet.rows[4].cells[0].value

      expect(worksheet.rows[1].cells[0].value).to eq('Updating your commodity watch list:')
      expect(worksheet.rows[2].cells[0].value).to eq('All your active and expired codes, as well as errors, are listed on this spreadsheet.')
      expect(worksheet.rows[3].cells[0].value).to eq('You can edit, add and remove codes from this spreadsheet or your own.')
      expect(final_instruction).to be_a(Axlsx::RichText)
      expect(final_instruction.map(&:value).join).to eq('You can then upload it to update your commodity watchlist. Ensure all codes are listed in column A.')
      expect(final_instruction.last.value).to eq('Ensure all codes are listed in column A.')
      expect(final_instruction.last.b).to be true
      expect(merged_cells).to be_empty
    end

    it 'uses 14pt font in instruction rows and 16pt bold for the first line' do
      styles = package.workbook.styles
      first_instruction_cell = worksheet.rows[1].cells[0]
      second_instruction_cell = worksheet.rows[2].cells[0]

      first_font = styles.fonts[styles.cellXfs[first_instruction_cell.style].fontId]
      second_font = styles.fonts[styles.cellXfs[second_instruction_cell.style].fontId]

      expect(first_font.sz.to_i).to eq(16)
      expect(first_font.b).to be true
      expect(second_font.sz.to_i).to eq(14)
    end

    it 'adds a replace all upload link row before the table' do
      link_row = worksheet.rows[5]
      merged_cells = Array(worksheet.instance_variable_get(:@merged_cells))

      expect(link_row.cells[0].value).to eq('Replace all commodities (upload)')
      expect(worksheet.hyperlinks.map(&:location)).to include(
        builder_class::REPLACE_ALL_COMMODITIES_UPLOAD_URL,
      )
      expect(worksheet.hyperlinks.map(&:ref)).to include('A6')
      expect(merged_cells).not_to include('A6:D6')
    end

    it 'adds the expected header row' do
      header_row = worksheet.rows[7]
      headers = header_row.cells.map(&:value)
      expect(headers).to eq(%w[Commodity Chapter Description Status])
      expect(header_row.height).to eq(34)
    end

    it 'uses double-height blank rows for the spacer rows' do
      expect(worksheet.rows[6].height).to eq(builder_class::BLANK_ROW_HEIGHT)
    end

    it 'does not apply a bottom border to the title row' do
      styles = package.workbook.styles
      bordered_cells = [worksheet.rows[0].cells[0]]

      bordered_cells.each do |cell|
        xf = styles.cellXfs[cell.style]
        border_xml = styles.borders[xf.borderId].to_xml_string

        expect(border_xml).not_to include('style="medium"')
        expect(border_xml).not_to include('rgb="FF0B0C0C"')
      end
    end

    it 'does not apply a bottom border to intro rows' do
      styles = package.workbook.styles
      unbordered_cells = [worksheet.rows[1].cells[0]]

      unbordered_cells.each do |cell|
        xf = styles.cellXfs[cell.style]
        border_xml = styles.borders[xf.borderId].to_xml_string

        expect(border_xml).not_to include('style="medium"')
        expect(border_xml).not_to include('rgb="FF0B0C0C"')
      end
    end

    it 'uses filled cells in the blank intro rows to hide gridlines' do
      styles = package.workbook.styles
      blank_intro_rows = [worksheet.rows[6]]

      blank_intro_rows.each do |row|
        row.cells.each do |cell|
          xf = styles.cellXfs[cell.style]
          fill_xml = styles.fills[xf.fillId].to_xml_string

          expect(fill_xml).to include('patternType="solid"')
        end
      end
    end

    it 'indents table headers the same as table cells' do
      styles = package.workbook.styles
      header_cell = worksheet.rows[7].cells[0]
      first_data_cell = worksheet.rows[8].cells[0]

      header_alignment = styles.cellXfs[header_cell.style].alignment.to_xml_string
      data_alignment = styles.cellXfs[first_data_cell.style].alignment.to_xml_string

      expect(header_alignment).to include('indent="1"')
      expect(data_alignment).to include('indent="1"')
    end

    it 'adds rows ordered by commodity code with chapter, description and status' do
      data_rows = worksheet.rows[8..].map do |row|
        [
          row.cells[0].value.to_s,
          extract_cell_text(row.cells[1].value),
          extract_cell_text(row.cells[2].value),
          row.cells[3].value.to_s,
        ]
      end

      expect(data_rows).to eq([
        ["1111111111\n ", '11: Chapter eleven', "Expired commodity description\n", 'Expired'],
        ["2222222222\n ", '22: Chapter twenty two', "Active commodity\ndescription\n", 'Active'],
        ["3333333333\n ", 'Not applicable', 'Not applicable', 'Error from upload'],
      ])
    end

    it 'renders the final description level in bold rich text for valid rows' do
      expired_description = worksheet.rows[8].cells[2].value
      active_description = worksheet.rows[9].cells[2].value

      expect(expired_description).to be_a(Axlsx::RichText)
      expect(active_description).to be_a(Axlsx::RichText)
      expect(expired_description.first.b).to be true
      expect(active_description.first.b).to be true
    end

    it 'uses bold styling for values in the first table column' do
      first_data_cell = worksheet.rows[8].cells[0]
      font = package.workbook.styles.fonts[package.workbook.styles.cellXfs[first_data_cell.style].fontId]

      expect(font.b).to be true
    end

    it 'enables table built-in row striping' do
      table = worksheet.tables.first
      style_info = table.respond_to?(:table_style_info) ? table.table_style_info : nil

      expect(style_info).not_to be_nil
      expect(style_info.show_row_stripes).to be true
    end

    it 'does not force a fixed explicit row height for table rows' do
      data_rows = worksheet.rows[8..10]
      expect(data_rows.map(&:height)).to all(be_nil)
    end

    it 'applies requested status colors and bold 12pt text' do
      styles = package.workbook.styles
      status_cells = worksheet.rows[8..10].map { |row| row.cells[3] }

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
      expect(table.ref).to eq('A8:D10')
    end
  end

  describe '#load_classification_descriptions' do
    subject(:service) { described_class.new(active_codes, expired_codes, invalid_codes) }

    let(:codes) { %w[1111111111 2222222222] }

    it 'delegates to CachedCommodityDescriptionService.fetch_for_codes' do
      allow(CachedCommodityDescriptionService).to receive(:fetch_for_codes).with(codes, include_hierarchy: true).and_return(
        '1111111111' => { plain_description: 'Cached 111', hierarchy_levels: ['Cached 111'], has_heading: false },
        '2222222222' => { plain_description: 'Fetched 222', hierarchy_levels: ['Fetched 222'], has_heading: false },
      )

      result = service.send(:load_classification_descriptions, codes)

      expect(result).to eq(
        '1111111111' => { plain_description: 'Cached 111', hierarchy_levels: ['Cached 111'], has_heading: false },
        '2222222222' => { plain_description: 'Fetched 222', hierarchy_levels: ['Fetched 222'], has_heading: false },
      )
      expect(CachedCommodityDescriptionService).to have_received(:fetch_for_codes).with(codes, include_hierarchy: true)
    end
  end

  def extract_cell_text(value)
    return value.to_s unless value.is_a?(Axlsx::RichText)

    value.map(&:value).join
  end
end

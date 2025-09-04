RSpec.describe DeltaReportService::ExcelGenerator do
  let(:date) { Date.parse('2024-08-11') }
  let(:change_records) do
    [
      [
        {
          chapter: '01',
          commodity_code: '0101000000',
          commodity_code_description: 'Live horses',
          import_export: 'Import',
          measure_type: '103: Third country duty',
          geo_area: 'GB: United Kingdom',
          additional_code: 'A123: Special code',
          duty_expression: '10%',
          type_of_change: 'Measure added',
          change: 'new measure',
          date_of_effect: date,
          operation_date: date,
        },
        {
          chapter: '02',
          commodity_code: '0201000000',
          commodity_code_description: 'Meat of bovine animals',
          import_export: 'Export',
          measure_type: '104: Export duty',
          geo_area: 'US: United States',
          additional_code: nil,
          duty_expression: '5%',
          type_of_change: 'Measure updated',
          change: 'duty rate changed',
          date_of_effect: date + 1.day,
          operation_date: date,
        },
      ],
    ]
  end

  describe '.call' do
    context 'when change_records is empty' do
      it 'returns early without creating a package' do
        result = described_class.call([], date)
        expect(result).to be_nil
      end
    end

    context 'when change_records has data' do
      it 'creates a new instance and calls call method' do
        generator_instance = instance_double(described_class)
        allow(described_class).to receive(:new).with(change_records, date).and_return(generator_instance)
        allow(generator_instance).to receive(:call).and_return(instance_double(Axlsx::Package))

        result = described_class.call(change_records, date)

        expect(result).not_to be_nil
      end
    end
  end

  describe '#initialize' do
    let(:instance) { described_class.new(change_records, date) }

    it 'sets change_records and date' do
      expect(instance.change_records).to eq(change_records)
      expect(instance.dates).to eq(date)
    end
  end

  describe '#call' do
    let(:instance) { described_class.new(change_records, date) }
    let(:package) { instance_double(Axlsx::Package, serialize: true) }
    let(:workbook) { instance_double(Axlsx::Workbook) }
    let(:worksheet) { instance_double(Axlsx::Worksheet) }
    let(:styles) { instance_double(Axlsx::Styles) }

    before do
      allow(Axlsx::Package).to receive(:new).and_return(package)
      allow(package).to receive(:use_shared_strings=)
      allow(package).to receive(:workbook).and_return(workbook)
      allow(workbook).to receive(:styles).and_return(styles)
      allow(workbook).to receive(:add_worksheet).and_yield(worksheet)
      allow(worksheet).to receive_messages(
        add_row: nil,
        column_widths: nil,
        rows: [instance_double(Axlsx::Row, height: nil, 'height=' => nil)],
        merge_cells: nil,
        sheet_view: instance_double(Axlsx::SheetView, pane: nil),
      )
      allow(worksheet).to receive(:auto_filter=)
      allow(instance).to receive(:excel_cell_styles).and_return({
        pre_header: instance_double(Axlsx::Styles),
        pre_header_detail: instance_double(Axlsx::Styles),
        header: instance_double(Axlsx::Styles),
        header_detail: instance_double(Axlsx::Styles),
      })
      allow(Rails.env).to receive(:development?).and_return(false)
    end

    it 'creates an Axlsx package with shared strings enabled' do
      instance.call

      expect(Axlsx::Package).to have_received(:new)
      expect(package).to have_received(:use_shared_strings=).with(true)
    end

    it 'adds a worksheet with the correct name' do
      instance.call

      expect(workbook).to have_received(:add_worksheet).with(name: 'Delta Report')
    end

    it 'adds pre-header and header rows' do
      instance.call

      expect(worksheet).to have_received(:add_row).at_least(2).times
    end

    it 'adds rows for each change record' do
      instance.call

      expect(worksheet).to have_received(:add_row).at_least(change_records.size).times
    end

    it 'sets column widths' do
      instance.call

      expect(worksheet).to have_received(:column_widths)
    end

    context 'when in development environment' do
      before { allow(Rails.env).to receive(:development?).and_return(true) }

      it 'serializes the package to a local file' do
        instance.call

        expect(package).to have_received(:serialize).with("delta_report_#{date}.xlsx")
      end
    end

    it 'returns the package' do
      result = instance.call
      expect(result).to eq(package)
    end
  end

  describe '#excel_header_row' do
    let(:instance) { described_class.new(change_records, date) }

    it 'returns the correct header row' do
      expected_headers = [
        'Chapter',
        'Commodity Code',
        'Commodity description',
        'Import/Export',
        'Measure Type',
        'Measure Geo area',
        'Additional code',
        'Duty Expression',
        'Type of change',
        'Updated code/data',
        'Date of effect',
        'Operation Date',
      ]

      expect(instance.excel_header_row).to eq(expected_headers)
    end
  end

  describe '#excel_autofilter_range' do
    let(:instance) { described_class.new(change_records, date) }

    it 'returns the correct autofilter range' do
      expect(instance.excel_autofilter_range).to eq('A2:L2')
    end
  end

  describe '#excel_column_widths' do
    let(:instance) { described_class.new(change_records, date) }

    it 'returns an array of column widths' do
      widths = instance.excel_column_widths

      expect(widths).to be_an(Array)
      expect(widths.size).to eq(12)
      expect(widths[0]).to eq(15)  # Chapter
      expect(widths[1]).to eq(20)  # Commodity Code
      expect(widths[2]).to eq(50)  # Commodity Description
    end
  end

  describe '#excel_cell_types' do
    let(:instance) { described_class.new(change_records, date) }

    it 'returns an array of cell types' do
      types = instance.excel_cell_types

      expect(types).to be_an(Array)
      expect(types.size).to eq(12)
      expect(types).to all(eq(:string))
    end
  end

  describe '#build_excel_row' do
    let(:instance) { described_class.new(change_records, date) }
    let(:record) { change_records.first.first }

    it 'builds the correct row array from a record' do
      result = instance.build_excel_row(record)

      expect(result).to eq([
        '01',
        '0101000000',
        'Live horses',
        'Import',
        '103: Third country duty',
        'GB: United Kingdom',
        'A123: Special code',
        '10%',
        'Measure added',
        'new measure',
        '2024-08-11',
        date,
      ])
    end

    context 'when date_of_effect is nil' do
      let(:record) { change_records.first.first.merge(date_of_effect: nil) }

      it 'handles nil date_of_effect gracefully' do
        result = instance.build_excel_row(record)
        expect(result[10]).to be_nil
      end
    end
  end

  describe '#excel_cell_styles' do
    let(:instance) { described_class.new(change_records, date) }
    let(:workbook) { instance_double(Axlsx::Workbook) }
    let(:styles) { instance_double(Axlsx::Styles) }

    before do
      instance.workbook = workbook
      allow(workbook).to receive(:styles).and_return(styles)
      allow(styles).to receive(:add_style).and_return(instance_double(Axlsx::Styles))
    end

    it 'creates all necessary styles' do
      result = instance.excel_cell_styles

      expect(result).to have_key(:pre_header)
      expect(result).to have_key(:pre_header_detail)
      expect(result).to have_key(:header)
      expect(result).to have_key(:header_detail)
      expect(result).to have_key(:date)
      expect(result).to have_key(:commodity_code)
      expect(result).to have_key(:chapter)
      expect(result).to have_key(:text)
      expect(result).to have_key(:center_text)
      expect(result).to have_key(:change_added)
      expect(result).to have_key(:change_removed)
      expect(result).to have_key(:change_updated)
    end
  end

  describe '#build_row_styles' do
    let(:instance) { described_class.new(change_records, date) }
    let(:styles) do
      {
        chapter: 'chapter_style',
        commodity_code: 'commodity_code_style',
        text: 'text_style',
        date: 'date_style',
        change_added: 'change_added_style',
        change_removed: 'change_removed_style',
        change_updated: 'change_updated_style',
      }
    end

    context 'when type_of_change contains "added"' do
      let(:record) { { type_of_change: 'Measure added' } }

      it 'uses change_added style for type of change column' do
        result = instance.build_row_styles(styles, record)
        expect(result[8]).to eq('change_added_style')
      end
    end

    context 'when type_of_change contains "removed"' do
      let(:record) { { type_of_change: 'Measure removed' } }

      it 'uses change_removed style for type of change column' do
        result = instance.build_row_styles(styles, record)
        expect(result[8]).to eq('change_removed_style')
      end
    end

    context 'when type_of_change contains "updated"' do
      let(:record) { { type_of_change: 'Measure updated' } }

      it 'uses change_updated style for type of change column' do
        result = instance.build_row_styles(styles, record)
        expect(result[8]).to eq('change_updated_style')
      end
    end

    context 'when type_of_change is unrecognized' do
      let(:record) { { type_of_change: 'Unknown change' } }

      it 'uses change updated style for type of change column' do
        result = instance.build_row_styles(styles, record)
        expect(result[8]).to eq('change_updated_style')
      end
    end

    it 'returns the correct number of style elements' do
      record = { type_of_change: 'added' }
      result = instance.build_row_styles(styles, record)
      expect(result.size).to eq(12)
    end
  end
end

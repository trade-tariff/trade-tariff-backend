RSpec.describe Reporting::Differences::Renderers::Overview do
  describe '#add_worksheet' do
    let(:worksheet) do
      double(
        append_row: nil,
        last_row_number: 10,
        set_column_width: nil,
        write_url_opt: nil,
      )
    end
    let(:workbook) do
      double(
        add_format: :dashboard_style,
        get_worksheet_by_name: worksheet,
      )
    end
    let(:report) do
      double(
        as_of: '2026-07-21',
        bold_style: :bold_style,
        centered_style: :centered_style,
        regular_style: :regular_style,
        workbook:,
      )
    end

    it 'renders the overview dashboard through the report workbook interface' do
      described_class.new(report).add_worksheet(Object.new)

      expect(workbook).to have_received(:get_worksheet_by_name).with('Overview')
      expect(worksheet).to have_received(:append_row).at_least(:once)
      expect(worksheet).to have_received(:write_url_opt).at_least(:once)
      expect(worksheet).to have_received(:set_column_width).exactly(6).times
    end
  end
end

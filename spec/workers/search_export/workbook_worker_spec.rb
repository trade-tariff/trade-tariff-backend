RSpec.describe SearchExport::WorkbookWorker do
  let(:export) do
    SearchExport::WorkbookExport.create(
      service: TradeTariffBackend.service,
      from_date: Date.new(2026, 9, 23),
      to_date: Date.new(2026, 9, 24),
      status: 'queued',
    )
  end

  describe '#perform' do
    it 'marks the export failed when its range grows beyond the row limit' do
      allow(SearchExport::Workbook).to receive(:call).and_raise(SearchExport::Workbook::TooManyRows, 'Shorten the date range.')

      described_class.new.perform(export.id)

      expect(export.refresh).to have_attributes(status: 'failed', file: nil, error_message: 'Shorten the date range.')
    end

    it 'stores a safe failure message and propagates unexpected errors' do
      allow(SearchExport::Workbook).to receive(:call).and_raise(IOError, 'private filesystem path')

      expect { described_class.new.perform(export.id) }.to raise_error(IOError)
      expect(export.refresh).to have_attributes(status: 'failed', file: nil, error_message: 'The workbook could not be built.')
    end
  end
end

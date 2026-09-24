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
    it 'does not start a job whose queue deadline has passed' do
      SearchExport::WorkbookExport.where(id: export.id).update(updated_at: 16.minutes.ago)
      allow(SearchExport::Workbook).to receive(:call)

      described_class.new.perform(export.id)

      expect(export.refresh.status).to eq('failed')
      expect(SearchExport::Workbook).not_to have_received(:call)
    end

    it 'does not publish a result after another request expires the job' do
      allow(SearchExport::Workbook).to receive(:call) do
        SearchExport::WorkbookExport.where(id: export.id).update(status: 'failed')
        SearchExport::Workbook::Result.new(bytes: 'late', omitted_count: 0, row_count: 0)
      end

      described_class.new.perform(export.id)

      expect(export.refresh).to have_attributes(status: 'failed', file: nil)
    end

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

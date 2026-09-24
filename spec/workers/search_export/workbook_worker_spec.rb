RSpec.describe SearchExport::WorkbookWorker do
  include_context 'with workbook exports'

  let(:export) { SearchExport::WorkbookExport.create(from_date: Date.yesterday, to_date: Date.current) }
  let(:result) { SearchExport::Workbook::Result.new(bytes: 'workbook', row_count: 1, omitted_count: 0) }

  before { allow(SearchExport::Workbook).to receive(:call).and_return(result) }

  it 'builds in the worker and stores an expiring download' do
    described_class.new.perform(export.id)
    expect(export.payload).to include('status' => 'ready', 'row_count' => 1)
    expect(export.file).to eq('workbook')
    expect(SearchExport::Workbook).to have_received(:call).with(from: Date.yesterday, to: Date.current)
  end

  it 'does not repeat a delivered job' do
    2.times { described_class.new.perform(export.id) }
    expect(SearchExport::Workbook).to have_received(:call).once
  end

  it 'ignores an expired job' do
    id = export.id
    export.delete
    described_class.new.perform(id)
    expect(SearchExport::Workbook).not_to have_received(:call)
  end

  it 'does not build a stale queued job' do
    id = export.id
    travel 16.minutes do
      described_class.new.perform(id)
      expect(export.payload['status']).to eq('failed')
      expect(SearchExport::Workbook).not_to have_received(:call)
    end
  end

  it 'reports incomplete CloudWatch retrieval without a partial file' do
    allow(SearchExport::Workbook).to receive(:call).and_raise(SearchExport::CloudwatchReader::Error, 'Please shorten the date range.')
    described_class.new.perform(export.id)
    expect(export.payload).to include('status' => 'failed', 'error' => 'Please shorten the date range.')
    expect(export.file).to be_nil
  end

  it 'records a safe failure and re-raises unexpected errors' do
    allow(SearchExport::Workbook).to receive(:call).and_raise(StandardError, 'private details')
    expect { described_class.new.perform(export.id) }.to raise_error(StandardError)
    expect(export.payload).to include('status' => 'failed', 'error' => 'The workbook could not be built.')
  end
end

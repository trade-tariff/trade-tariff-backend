RSpec.describe ImportCustomsTariffDocumentWorker, type: :worker do
  subject(:perform) { described_class.new.perform }

  before do
    allow(CustomsTariffImporter::Instrumentation).to receive(:import_run_started)
    allow(CustomsTariffImporter::Instrumentation).to receive(:import_run_completed)
    allow(CustomsTariffImporter::Instrumentation).to receive(:import_run_failed)
  end

  def result(status:, version: nil, error: nil)
    CustomsTariffImporter::Importer::Result.new(status:, version:, error:)
  end

  context 'when one document is imported' do
    before do
      allow(CustomsTariffImporter::Importer).to receive(:new).and_return(
        instance_double(CustomsTariffImporter::Importer,
                        call: [result(status: :imported, version: '1.30')]),
      )
    end

    it 'emits import_run_started' do
      perform
      expect(CustomsTariffImporter::Instrumentation).to have_received(:import_run_started)
    end

    it 'emits import_run_completed with correct counts' do
      perform
      expect(CustomsTariffImporter::Instrumentation).to have_received(:import_run_completed).with(
        imported: 1,
        skipped: 0,
        failed: 0,
        duration_ms: a_kind_of(Float),
      )
    end
  end

  context 'when all documents are skipped' do
    before do
      allow(CustomsTariffImporter::Importer).to receive(:new).and_return(
        instance_double(CustomsTariffImporter::Importer,
                        call: [result(status: :skipped, version: '1.30')]),
      )
    end

    it 'emits import_run_completed with skipped: 1' do
      perform
      expect(CustomsTariffImporter::Instrumentation).to have_received(:import_run_completed).with(
        hash_including(imported: 0, skipped: 1, failed: 0),
      )
    end
  end

  context 'when a document import fails' do
    before do
      allow(CustomsTariffImporter::Importer).to receive(:new).and_return(
        instance_double(CustomsTariffImporter::Importer,
                        call: [result(status: :failed, error: 'HTTP 503')]),
      )
    end

    it 'emits import_run_completed with failed: 1' do
      perform
      expect(CustomsTariffImporter::Instrumentation).to have_received(:import_run_completed).with(
        hash_including(imported: 0, skipped: 0, failed: 1),
      )
    end
  end

  context 'when the importer raises an unexpected exception' do
    before do
      allow(CustomsTariffImporter::Importer).to receive(:new).and_return(
        instance_double(CustomsTariffImporter::Importer).tap do |dbl|
          allow(dbl).to receive(:call).and_raise(RuntimeError, 'catastrophic failure')
        end,
      )
    end

    it 'emits import_run_failed' do
      expect { perform }.to raise_error(RuntimeError)
      expect(CustomsTariffImporter::Instrumentation).to have_received(:import_run_failed).with(
        error_class: 'RuntimeError',
        error_message: 'catastrophic failure',
      )
    end
  end
end

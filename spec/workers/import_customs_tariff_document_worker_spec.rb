RSpec.describe ImportCustomsTariffDocumentWorker, type: :worker do
  subject(:perform) { described_class.new.perform }

  before do
    allow(SlackNotifierService).to receive(:call)
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
      create(:customs_tariff_update)

      perform
      expect(CustomsTariffImporter::Instrumentation).to have_received(:import_run_completed).with(
        imported: 1,
        skipped: 0,
        failed: 0,
        duration_ms: a_kind_of(Float),
        review_backlog: 1,
      )
    end

    it 'notifies Slack that the import completed successfully' do
      perform

      expect(SlackNotifierService).to have_received(:call).with(
        include('Customs tariff document import completed', 'imported: 1', 'skipped: 0', 'failed: 0'),
      )
    end

    context 'when Slack notification fails' do
      before do
        allow(SlackNotifierService).to receive(:call).and_raise(Slack::Notifier::APIError, 'Slack timeout')
      end

      it 'does not fail the import job' do
        expect { perform }.not_to raise_error

        expect(CustomsTariffImporter::Instrumentation).to have_received(:import_run_completed)
      end
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

    it 'does not notify Slack' do
      perform

      expect(SlackNotifierService).not_to have_received(:call)
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

    it 'notifies Slack that the import completed with failures' do
      perform

      expect(SlackNotifierService).to have_received(:call).with(
        include('Customs tariff document import completed with failures', 'failed: 1'),
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

    it 'notifies Slack that the import failed unexpectedly' do
      expect { perform }.to raise_error(RuntimeError)

      expect(SlackNotifierService).to have_received(:call).with(
        include('Customs tariff document import failed', 'RuntimeError', 'catastrophic failure'),
      )
    end

    context 'when Slack notification fails' do
      before do
        allow(SlackNotifierService).to receive(:call).and_raise(Slack::Notifier::APIError, 'Slack timeout')
      end

      it 're-raises the original import error' do
        expect { perform }.to raise_error(RuntimeError, 'catastrophic failure')
      end
    end
  end
end

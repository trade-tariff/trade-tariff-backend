RSpec.describe ImportCustomsTariffDocumentWorker, type: :worker do
  subject(:perform) { described_class.new.perform }

  let(:importer_double) { instance_double(CustomsTariffImporter::Importer) }

  before do
    allow(TradeTariffBackend).to receive(:uk?).and_return(true)
    allow(CustomsTariffImporter::Importer).to receive(:new).and_return(importer_double)
    allow(SlackNotifierService).to receive(:call)
    allow(CustomsTariffImporter::Instrumentation).to receive(:import_run_started)
    allow(CustomsTariffImporter::Instrumentation).to receive(:import_run_completed)
    allow(CustomsTariffImporter::Instrumentation).to receive(:import_run_failed)
    allow(CustomsTariffUpdateNotifierService).to receive(:new).and_return(instance_double(CustomsTariffUpdateNotifierService, call: nil))
  end

  context 'when SERVICE is not uk' do
    before { allow(TradeTariffBackend).to receive(:uk?).and_return(false) }

    it 'is a no-op' do
      perform
      expect(CustomsTariffImporter::Importer).not_to have_received(:new)
    end
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
        failed: 0,
        duration_ms: a_kind_of(Float),
      )
    end

    it 'does not send a Slack notification for a successful import' do
      perform
      expect(SlackNotifierService).not_to have_received(:call)
    end

    it 'calls CustomsTariffUpdateNotifierService for the imported version' do
      allow(CustomsTariffUpdateNotifierService).to receive(:new).and_return(instance_double(CustomsTariffUpdateNotifierService, call: nil))

      perform

      expect(CustomsTariffUpdateNotifierService).to have_received(:new).with('1.30')
    end
  end

  context 'when the notifier raises for one of several imported results' do
    before do
      allow(CustomsTariffImporter::Importer).to receive(:new).and_return(
        instance_double(CustomsTariffImporter::Importer,
                        call: [
                          result(status: :imported, version: '1.30'),
                          result(status: :imported, version: '1.31'),
                        ]),
      )

      notifier_1_30 = instance_double(CustomsTariffUpdateNotifierService)
      allow(notifier_1_30).to receive(:call).and_raise(RuntimeError, 'notify boom')
      notifier_1_31 = instance_double(CustomsTariffUpdateNotifierService, call: nil)

      allow(CustomsTariffUpdateNotifierService).to receive(:new).with('1.30').and_return(notifier_1_30)
      allow(CustomsTariffUpdateNotifierService).to receive(:new).with('1.31').and_return(notifier_1_31)
      allow(Rails.logger).to receive(:error)
    end

    it 'still reports the import as completed successfully' do
      perform

      expect(CustomsTariffImporter::Instrumentation).to have_received(:import_run_completed).with(
        imported: 2,
        failed: 0,
        duration_ms: a_kind_of(Float),
      )
      expect(SlackNotifierService).to have_received(:call).with(
        include('Customs tariff document import completed', 'imported: 2'),
      )
      expect(CustomsTariffImporter::Instrumentation).not_to have_received(:import_run_failed)
    end

    it 'does not re-raise the notifier error' do
      expect { perform }.not_to raise_error
    end

    it 'still calls the notifier for the later document even though the earlier one raised' do
      perform

      expect(CustomsTariffUpdateNotifierService).to have_received(:new).with('1.30')
      expect(CustomsTariffUpdateNotifierService).to have_received(:new).with('1.31')
    end

    it 'logs the failure with identifying detail via Rails.logger.error' do
      perform

      expect(Rails.logger).to have_received(:error).with(
        a_string_including('1.30', 'RuntimeError', 'notify boom'),
      )
    end

    it 'posts a distinct Slack message making clear the import succeeded but the notification failed' do
      perform

      expect(SlackNotifierService).to have_received(:call).with(
        a_string_including('notification failed', '1.30'),
      )
    end
  end

  context 'when a document is skipped for duplicate content' do
    before do
      allow(CustomsTariffImporter::Importer).to receive(:new).and_return(
        instance_double(CustomsTariffImporter::Importer,
                        call: [result(status: :duplicate_content, version: '1.30')]),
      )
    end

    it 'does not call CustomsTariffUpdateNotifierService' do
      allow(CustomsTariffUpdateNotifierService).to receive(:new)

      perform

      expect(CustomsTariffUpdateNotifierService).not_to have_received(:new)
    end
  end

  context 'when all documents are skipped' do
    before do
      allow(CustomsTariffImporter::Importer).to receive(:new).and_return(
        instance_double(CustomsTariffImporter::Importer,
                        call: [result(status: :skipped, version: '1.30')]),
      )
    end

    it 'emits import_run_completed with imported: 0, failed: 0' do
      perform
      expect(CustomsTariffImporter::Instrumentation).to have_received(:import_run_completed).with(
        hash_including(imported: 0, failed: 0),
      )
    end

    it 'does not send a Slack notification when there is nothing to import' do
      perform
      expect(SlackNotifierService).not_to have_received(:call)
    end

    it 'does not call CustomsTariffUpdateNotifierService' do
      allow(CustomsTariffUpdateNotifierService).to receive(:new)

      perform

      expect(CustomsTariffUpdateNotifierService).not_to have_received(:new)
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
        hash_including(imported: 0, failed: 1),
      )
    end

    it 'notifies Slack that the import completed with failures' do
      perform

      expect(SlackNotifierService).to have_received(:call).with(
        include('Customs tariff document import completed with failures', 'Version ID:'),
      )
    end

    it 'does not call CustomsTariffUpdateNotifierService' do
      allow(CustomsTariffUpdateNotifierService).to receive(:new)

      perform

      expect(CustomsTariffUpdateNotifierService).not_to have_received(:new)
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

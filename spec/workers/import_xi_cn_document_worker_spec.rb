require 'rails_helper'

RSpec.describe ImportXiCnDocumentWorker do
  subject(:worker) { described_class.new }

  let(:importer_double) { instance_double(XiCnImporter::Importer) }

  before do
    allow(TradeTariffBackend).to receive(:xi?).and_return(true)
    allow(XiCnImporter::Importer).to receive(:new).and_return(importer_double)
    allow(SlackNotifierService).to receive(:call)
    allow(CustomsTariffUpdateNotifierService).to receive(:new).and_return(instance_double(CustomsTariffUpdateNotifierService, call: nil))
  end

  describe '#perform' do
    context 'when SERVICE is not xi' do
      before { allow(TradeTariffBackend).to receive(:xi?).and_return(false) }

      it 'does nothing' do
        worker.perform
        expect(XiCnImporter::Importer).not_to have_received(:new)
      end
    end

    context 'when documents are imported' do
      before do
        allow(importer_double).to receive(:call).and_return([
          XiCnImporter::Importer::Result.new(status: :imported, celex: '32025R1926'),
        ])
      end

      it 'does not send a Slack notification for a successful import' do
        worker.perform
        expect(SlackNotifierService).not_to have_received(:call)
      end

      it 'calls CustomsTariffUpdateNotifierService for the imported celex id' do
        allow(CustomsTariffUpdateNotifierService).to receive(:new).and_return(instance_double(CustomsTariffUpdateNotifierService, call: nil))

        worker.perform

        expect(CustomsTariffUpdateNotifierService).to have_received(:new).with('32025R1926')
      end
    end

    context 'when the notifier raises for one of several imported results' do
      before do
        allow(importer_double).to receive(:call).and_return([
          XiCnImporter::Importer::Result.new(status: :imported, celex: '32025R1926'),
          XiCnImporter::Importer::Result.new(status: :imported, celex: '32025R1927'),
        ])

        notifier_1926 = instance_double(CustomsTariffUpdateNotifierService)
        allow(notifier_1926).to receive(:call).and_raise(RuntimeError, 'notify boom')
        notifier_1927 = instance_double(CustomsTariffUpdateNotifierService, call: nil)

        allow(CustomsTariffUpdateNotifierService).to receive(:new).with('32025R1926').and_return(notifier_1926)
        allow(CustomsTariffUpdateNotifierService).to receive(:new).with('32025R1927').and_return(notifier_1927)
        allow(Rails.logger).to receive(:error)
      end

      it 'does not re-raise the notifier error' do
        expect { worker.perform }.not_to raise_error
      end

      it 'still calls the notifier for the later document even though the earlier one raised' do
        worker.perform

        expect(CustomsTariffUpdateNotifierService).to have_received(:new).with('32025R1926')
        expect(CustomsTariffUpdateNotifierService).to have_received(:new).with('32025R1927')
      end

      it 'logs the failure with identifying detail via Rails.logger.error' do
        worker.perform

        expect(Rails.logger).to have_received(:error).with(
          a_string_including('32025R1926', 'RuntimeError', 'notify boom'),
        )
      end

      it 'posts a distinct Slack message making clear the import succeeded but the notification failed' do
        worker.perform

        expect(SlackNotifierService).to have_received(:call).with(
          a_string_including('notification failed', '32025R1926'),
        )
      end
    end

    context 'when no new documents are found' do
      before do
        allow(importer_double).to receive(:call).and_return([])
      end

      it 'does not send a Slack notification when there is nothing to import' do
        worker.perform
        expect(SlackNotifierService).not_to have_received(:call)
      end
    end

    context 'when a document import fails' do
      before do
        allow(importer_double).to receive(:call).and_return([
          XiCnImporter::Importer::Result.new(status: :failed, celex: '32025R1926', error: 'HTTP 503'),
        ])
      end

      it 'sends a failure Slack notification' do
        worker.perform
        expect(SlackNotifierService).to have_received(:call)
          .with(a_string_including('XI Combined Nomenclature document import completed with failures', 'CELEX ID:'))
      end

      it 'does not call CustomsTariffUpdateNotifierService' do
        allow(CustomsTariffUpdateNotifierService).to receive(:new)

        worker.perform

        expect(CustomsTariffUpdateNotifierService).not_to have_received(:new)
      end
    end

    context 'when the importer raises an error' do
      before do
        allow(importer_double).to receive(:call).and_raise(RuntimeError, 'network timeout')
      end

      it 'sends a failure Slack notification' do
        expect { worker.perform }.to raise_error(RuntimeError)
        expect(SlackNotifierService).to have_received(:call)
          .with(a_string_including('failed'))
      end
    end
  end
end

require 'rails_helper'

RSpec.describe ImportXiCnDocumentWorker do
  subject(:worker) { described_class.new }

  let(:importer_double) { instance_double(XiCnImporter::Importer) }

  before do
    allow(TradeTariffBackend).to receive(:xi?).and_return(true)
    allow(XiCnImporter::Importer).to receive(:new).and_return(importer_double)
    allow(SlackNotifierService).to receive(:call)
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

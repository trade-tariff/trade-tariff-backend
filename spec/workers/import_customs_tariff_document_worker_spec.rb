RSpec.describe ImportCustomsTariffDocumentWorker, type: :worker do
  subject(:perform) { described_class.new.perform }

  before { allow(SlackNotifierService).to receive(:call) }

  def result(status:, version: nil, error: nil)
    ImportCustomsTariffDocumentService::Result.new(status:, version:, error:)
  end

  context 'when one document is imported' do
    before do
      allow(ImportCustomsTariffDocumentService).to receive(:new).and_return(
        instance_double(ImportCustomsTariffDocumentService,
                        call: [result(status: :imported, version: '1.30')]),
      )
    end

    it 'sends a Slack notification listing the imported version' do
      perform
      expect(SlackNotifierService).to have_received(:call).with(
        'Customs Tariff documents imported: versions 1.30 — pending approval',
      )
    end
  end

  context 'when multiple documents are imported' do
    before do
      allow(ImportCustomsTariffDocumentService).to receive(:new).and_return(
        instance_double(ImportCustomsTariffDocumentService,
                        call: [
                          result(status: :imported, version: '1.30'),
                          result(status: :imported, version: '1.31'),
                        ]),
      )
    end

    it 'sends a single Slack notification listing all imported versions' do
      perform
      expect(SlackNotifierService).to have_received(:call).with(
        'Customs Tariff documents imported: versions 1.30, 1.31 — pending approval',
      )
    end
  end

  context 'when all documents are skipped (versions already exist)' do
    before do
      allow(ImportCustomsTariffDocumentService).to receive(:new).and_return(
        instance_double(ImportCustomsTariffDocumentService,
                        call: [result(status: :skipped, version: '1.30')]),
      )
    end

    it 'does not send a Slack notification' do
      perform
      expect(SlackNotifierService).not_to have_received(:call)
    end
  end

  context 'when the import fails' do
    before do
      allow(ImportCustomsTariffDocumentService).to receive(:new).and_return(
        instance_double(ImportCustomsTariffDocumentService,
                        call: [result(status: :failed, error: 'HTTP 503')]),
      )
    end

    it 'sends a failure Slack notification' do
      perform
      expect(SlackNotifierService).to have_received(:call).with(
        'Customs Tariff document import failed: HTTP 503',
      )
    end
  end
end

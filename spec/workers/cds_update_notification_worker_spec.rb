RSpec.describe CdsUpdateNotificationWorker, type: :worker do
  subject(:perform) { described_class.new.perform(notification_id) }

  let(:notification_id) { 1 }
  let(:cds_update) { instance_double(TariffSynchronizer::CdsUpdate, filename: 'test.gzip') }
  let(:notification) { instance_double(CdsUpdateNotification, cds_update:) }
  let(:importer) { instance_double(CdsImporter, import: nil) }

  before do
    allow(TradeTariffBackend).to receive(:uk?).and_return(true)
    allow(CdsUpdateNotification).to receive(:find).with(id: notification_id).and_return(notification)
    allow(CdsImporter).to receive(:new).and_return(importer)
  end

  it 'alerts on a dead job, because slack_alerts is not disabled for this worker' do
    expect(described_class.sidekiq_options['slack_alerts']).to be_nil
  end

  context 'when the notification exists' do
    it 'generates the spreadsheet' do
      perform

      expect(CdsImporter).to have_received(:new).with(cds_update, handler_classes: [CdsImporter::ExcelWriter])
    end
  end

  context 'when the notification no longer exists' do
    before do
      allow(CdsUpdateNotification).to receive(:find).with(id: notification_id).and_return(nil)
    end

    it 'raises so the job dies loudly instead of reporting success' do
      expect { perform }.to raise_error(described_class::MissingNotificationError, /1/)
    end
  end

  context 'when the writer reports a failure' do
    before do
      allow(importer).to receive(:import) do
        ActiveSupport::Notifications.instrument(
          CdsImporter::ExcelWriter::FAILURE_EVENT,
          filename: 'test.gzip',
          message: 'CDS Updates excel: delivery failed',
        )
      end
    end

    it 'raises so the job does not report success without a spreadsheet' do
      expect { perform }.to raise_error(described_class::ReportFailedError, /delivery failed/)
    end
  end

  context 'when another file reports a failure concurrently' do
    before do
      allow(importer).to receive(:import) do
        ActiveSupport::Notifications.instrument(
          CdsImporter::ExcelWriter::FAILURE_EVENT,
          filename: 'other.gzip',
          message: 'CDS Updates excel: delivery failed',
        )
      end
    end

    it 'ignores the failure' do
      expect { perform }.not_to raise_error
    end
  end

  context 'when the service is XI' do
    before do
      allow(TradeTariffBackend).to receive(:uk?).and_return(false)
    end

    it 'does nothing' do
      perform

      expect(CdsImporter).not_to have_received(:new)
    end
  end
end

RSpec.describe TariffSynchronizer::BaseUpdateImporter do
  let(:taric_update) { create :taric_update, :pending }
  let(:base_update_importer) { described_class.new(taric_update) }

  describe '#apply', :truncation do
    before do
      allow(TradeTariffBackend).to receive(:service).and_return('xi')
    end

    it 'delegates import to TaricUpdateImporter' do
      allow(TariffSynchronizer::TaricUpdateImporter).to receive(:perform)

      base_update_importer.apply

      expect(TariffSynchronizer::TaricUpdateImporter).to have_received(:perform).with(taric_update)
    end

    context 'with a pending CDS update' do
      let(:cds_update) { create :cds_update, :pending }

      before do
        allow(TradeTariffBackend).to receive(:service).and_return('uk')
        allow(TariffSynchronizer::CdsUpdateImporter).to receive(:perform)
      end

      it 'delegates import to CdsUpdateImporter' do
        described_class.new(cds_update).apply

        expect(TariffSynchronizer::CdsUpdateImporter).to have_received(:perform).with(cds_update)
      end
    end

    it 'do not call TaricUpdateImporter if the update is not pending' do
      allow(TariffSynchronizer::TaricUpdateImporter).to receive(:perform)

      taric_update.mark_as_failed

      base_update_importer.apply

      expect(TariffSynchronizer::TaricUpdateImporter).not_to have_received(:perform)
    end

    it 'marks the record as failed if an error occurs' do
      allow(TariffSynchronizer::TaricUpdateImporter).to receive(:perform).and_raise(Sequel::Rollback)
      base_update_importer.apply

      expect(taric_update.reload).to be_failed
    end

    it 'updates the record with the exception if an error occurs' do
      base_update_importer.apply

      expect(taric_update.reload).to be_failed
      expect(taric_update.exception_backtrace).to include('lib/taric_importer.rb:')
      expect(taric_update.exception_queries).to include('(Sequel::Postgres::Database) ROLLBACK')
    end

    it 'subscribes to all events' do
      allow(ActiveSupport::Notifications).to receive(:subscribe)
      allow(TariffSynchronizer::TaricUpdateImporter).to receive(:perform)

      base_update_importer.apply

      expect(ActiveSupport::Notifications).to have_received(:subscribe).with(/sql\.sequel/)
      expect(ActiveSupport::Notifications).to have_received(:subscribe).with(/presence_error/)
      expect(ActiveSupport::Notifications).not_to have_received(:subscribe).with(/cds_error/)
    end

    it 'emits instrumentation event and sends an email' do
      allow(TariffSynchronizer::Instrumentation).to receive(:file_import_failed)
      base_update_importer.apply

      expect(TariffSynchronizer::Instrumentation).to have_received(:file_import_failed)

      expect(ActionMailer::Base.deliveries).not_to be_empty
      email = ActionMailer::Base.deliveries.last
      expect(email.subject).to include('Failed Trade Tariff update')
      expect(email.encoded).to include('Backtrace')
      expect(email.encoded).to include('(Sequel::Postgres::Database) ROLLBACK')
    end
  end
end

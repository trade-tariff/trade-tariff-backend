RSpec.describe TariffSynchronizer::BaseUpdateImporter do
  let(:base_update_importer) { described_class.new(update) }

  shared_examples 'a base update importer' do
    describe '#apply', :truncation do
      before do
        allow(TradeTariffBackend).to receive(:service).and_return(service)
      end

      it 'calls the import! method to the object' do
        allow(update).to receive(:import!)

        base_update_importer.apply

        expect(update).to have_received(:import!)
      end

      it 'do not call the import! method to the object if is not pending' do
        allow(update).to receive(:import!)

        update.mark_as_failed

        expect(update).not_to have_received(:import!)

        base_update_importer.apply
      end

      it 'marks the record as failed if an error occurs' do
        allow(update).to receive(:import!).and_raise(Sequel::Rollback)
        base_update_importer.apply

        expect(update.reload).to be_failed
      end

      it 'updates the record with the exception if an error occurs', :aggregate_failures do
        base_update_importer.apply

        expect(update.reload).to be_failed
        expect(update.exception_backtrace).to include(backtrace_fragment)
        expect(update.exception_queries).to include('UPDATE "tariff_updates" SET "state" = \'F\'')
      end

      it 'subscribes to all events' do
        allow(ActiveSupport::Notifications).to receive(:subscribe)
        allow(update).to receive(:import!).and_return(true)

        base_update_importer.apply

        expect(ActiveSupport::Notifications).to have_received(:subscribe).with(/sql\.sequel/)
        expect(ActiveSupport::Notifications).to have_received(:subscribe).with(/presence_error/)
        expect(ActiveSupport::Notifications).not_to have_received(:subscribe).with(/cds_error/)
      end

      it 'emits instrumentation event and sends an email', :aggregate_failures do
        allow(TariffSynchronizer::Instrumentation).to receive(:file_import_failed)
        base_update_importer.apply

        expect(TariffSynchronizer::Instrumentation).to have_received(:file_import_failed)

        expect(ActionMailer::Base.deliveries).not_to be_empty
        email = ActionMailer::Base.deliveries.last
        expect(email.subject).to include('Failed Trade Tariff update')
        expect(email.encoded).to include('Backtrace')
      end
    end
  end

  context 'with a TARIC update' do
    let(:update) { create :taric_update, :pending }
    let(:service) { 'xi' }
    let(:backtrace_fragment) { 'lib/taric_importer.rb:' }

    it_behaves_like 'a base update importer'
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

  context 'with a TARIC update that fails with a nested import error', :truncation do
    let(:update) { create :taric_update, :pending }

    before do
      allow(TradeTariffBackend).to receive(:service).and_return('xi')
      ExplicitAbrogationRegulation.unrestrict_primary_key
      allow(update).to receive(:file_path)
        .and_return('spec/fixtures/taric_samples/unknown_record.xml')
    end

    after { ExplicitAbrogationRegulation.restrict_primary_key }

    it 'persists the specific inner error, not the generic outer wrapper', :aggregate_failures do
      base_update_importer.apply

      expect(update.reload).to be_failed
      expect(update.exception_class).to include('TaricImporter::UnknownOperationError')
      expect(update.exception_class).to include('Unknown TARIC operation:')
      expect(update.exception_class).not_to include('TARIC record import failed')
    end
  end
end

RSpec.describe TariffSynchronizer::BaseUpdateImporter do
  let(:taric_update) { create :taric_update, :pending }
  let(:base_update_importer) { described_class.new(taric_update) }

  describe '#apply', :truncation do
    before do
      allow(TradeTariffBackend).to receive(:service).and_return('xi')
    end

    it 'calls the import! method to the object' do
      allow(taric_update).to receive(:import!)

      base_update_importer.apply

      expect(taric_update).to have_received(:import!)
    end

    it 'do not call the import! method to the object if is not pending' do
      allow(taric_update).to receive(:import!)

      taric_update.mark_as_failed

      expect(taric_update).not_to have_received(:import!)

      base_update_importer.apply
    end

    it 'marks the record as failed if an error occurs' do
      allow(taric_update).to receive(:import!).and_raise(Sequel::Rollback)
      base_update_importer.apply

      expect(taric_update.reload).to be_failed
    end

    it 'updates the record with the exception if an error occurs' do
      expect { base_update_importer.apply }.to raise_error(Sequel::Error)

      expect(taric_update.reload).to be_failed
      expect(taric_update.exception_backtrace).to include('lib/taric_importer.rb:')
      expect(taric_update.exception_queries).to include('(Sequel::Postgres::Database) ROLLBACK')
    end

    it 'subscribes to all events' do
      allow(ActiveSupport::Notifications).to receive(:subscribe)
      allow(taric_update).to receive(:import!).and_return(true)

      base_update_importer.apply

      expect(ActiveSupport::Notifications).to have_received(:subscribe).with(/sql\.sequel/)
      expect(ActiveSupport::Notifications).to have_received(:subscribe).with(/presence_error/)
      expect(ActiveSupport::Notifications).to have_received(:subscribe).with(/cds_error/)
    end

    it 'emits instrumentation event and sends an email' do
      allow(TariffSynchronizer::Instrumentation).to receive(:file_import_failed)
      expect { base_update_importer.apply }.to raise_error(Sequel::Error)

      expect(TariffSynchronizer::Instrumentation).to have_received(:file_import_failed)

      expect(ActionMailer::Base.deliveries).not_to be_empty
      email = ActionMailer::Base.deliveries.last
      expect(email.subject).to include('Failed Trade Tariff update')
      expect(email.encoded).to include('Backtrace')
      expect(email.encoded).to include('(Sequel::Postgres::Database) ROLLBACK')
    end
  end
  # rubocop:enable RSpec/MultipleExpectations
end

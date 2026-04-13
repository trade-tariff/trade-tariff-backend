RSpec.describe TariffSynchronizer::BaseUpdateImporter do
  describe '.perform', :truncation do
    context 'when import! raises' do
      let(:cds_update) { create(:cds_update, :pending) }

      before do
        allow(cds_update).to receive(:import!).and_raise(StandardError, 'batch insert failed')
        allow(TariffSynchronizer::TariffLogger).to receive(:failed_update)
      end

      it 'marks the update as failed' do
        begin
          described_class.perform(cds_update)
        rescue StandardError
          nil
        end

        expect(cds_update.reload.state).to eq('F')
      end
    end
  end

  describe '#keep_record_of_cds_errors', :truncation do
    let(:cds_update) { create(:cds_update, :pending) }

    it 'creates a cds error record when the notification has no :record' do
      importer = described_class.new(cds_update)
      importer.send(:keep_record_of_cds_errors)

      expect {
        ActiveSupport::Notifications.instrument('cds_error.cds_importer',
                                                type: 'SomeOperation',
                                                exception: StandardError.new('batch failed'))
      }.to change(TariffSynchronizer::TariffUpdateCdsError, :count).by(1)
    end
  end
end

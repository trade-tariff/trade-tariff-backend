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
end

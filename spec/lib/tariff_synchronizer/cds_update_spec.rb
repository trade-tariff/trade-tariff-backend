RSpec.describe TariffSynchronizer::CdsUpdate do
  describe 'batch insert failure', :truncation do
    let(:cds_update) { create(:cds_update, :pending) }
    let(:fake_importer) { instance_double(CdsImporter) }

    before do
      allow(CdsImporter).to receive(:new).and_return(fake_importer)
      allow(fake_importer).to receive(:import).and_raise(StandardError, 'constraint violation')
      allow(TariffSynchronizer::TariffLogger).to receive(:failed_update)
    end

    it 'marks the update as failed, not applied' do
      begin
        TariffSynchronizer::BaseUpdateImporter.perform(cds_update)
      rescue StandardError
        nil
      end

      expect(cds_update.reload.state).to eq('F')
    end
  end
end

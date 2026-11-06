RSpec.describe CdsUpdateNotification do
  describe 'validations' do
    context 'with correct info' do
      let(:notification) { build :cds_update_notification }

      it 'is a valid entity' do
        expect(notification).to be_valid
      end
    end

    context 'with incorrect date provided' do
      let(:notification) { build :cds_update_notification, filename: nil }

      it 'is not a valid entity' do
        expect(notification).not_to be_valid
      end
    end
  end

  describe 'creating' do
    it 'does not enqueue a worker (the controller does that)' do
      allow(CdsUpdateNotificationWorker).to receive(:perform_async)

      create :cds_update_notification

      expect(CdsUpdateNotificationWorker).not_to have_received(:perform_async)
    end

    it 'does not default whodunnit from the current request' do
      TradeTariffRequest.whodunnit = 'request-user'

      expect(build(:cds_update_notification, whodunnit: nil)).not_to be_valid
    ensure
      TradeTariffRequest.reset
    end
  end
end

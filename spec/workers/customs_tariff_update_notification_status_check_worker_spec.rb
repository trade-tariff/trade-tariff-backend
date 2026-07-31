RSpec.describe CustomsTariffUpdateNotificationStatusCheckWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    it 'delegates to Notifications::DeliveryStatusChecker with the customs_tariff_update pipeline and the version as identifier' do
      checker = instance_double(Notifications::DeliveryStatusChecker, call: nil)
      allow(Notifications::DeliveryStatusChecker).to receive(:new).and_return(checker)

      worker.perform('1.30', 'abc-123')

      expect(Notifications::DeliveryStatusChecker).to have_received(:new).with(
        'abc-123', pipeline: 'customs_tariff_update', identifier: '1.30'
      )
      expect(checker).to have_received(:call)
    end
  end
end

RSpec.describe Appendix5aNotificationStatusCheckWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    it 'delegates to Notifications::DeliveryStatusChecker with the appendix5a pipeline and the recipient index as identifier' do
      checker = instance_double(Notifications::DeliveryStatusChecker, call: nil)
      allow(Notifications::DeliveryStatusChecker).to receive(:new).and_return(checker)

      worker.perform(0, 'abc-123')

      expect(Notifications::DeliveryStatusChecker).to have_received(:new).with(
        'abc-123', pipeline: 'appendix5a', identifier: 0
      )
      expect(checker).to have_received(:call)
    end
  end

  describe 'sidekiq options' do
    it 'caps retries below Sidekiq default' do
      expect(described_class.sidekiq_options['retry']).to eq(3)
    end
  end
end

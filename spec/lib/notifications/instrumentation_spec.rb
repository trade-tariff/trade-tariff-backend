RSpec.describe Notifications::Instrumentation do
  describe '.send_skipped' do
    it 'emits send_skipped with the pipeline, identifier and reason' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      described_class.send_skipped(pipeline: 'customs_tariff_update', identifier: '1.30', reason: 'recipient_not_configured')
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'send_skipped.notifications',
        hash_including(pipeline: 'customs_tariff_update', identifier: '1.30', reason: 'recipient_not_configured'),
      )
    end
  end

  describe '.enqueue_retrying' do
    it 'emits enqueue_retrying with the pipeline, item, attempt and error details' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      described_class.enqueue_retrying(pipeline: 'customs_tariff_update', item: '1.30', attempt: 1, error_class: 'RuntimeError', error_message: 'boom')
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'enqueue_retrying.notifications',
        hash_including(pipeline: 'customs_tariff_update', item: '1.30', attempt: 1, error_class: 'RuntimeError', error_message: 'boom'),
      )
    end
  end

  describe '.enqueue_failed' do
    it 'emits enqueue_failed with the pipeline, items and attempts' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      described_class.enqueue_failed(pipeline: 'customs_tariff_update', items: ['1.30'], attempts: 3)
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'enqueue_failed.notifications',
        hash_including(pipeline: 'customs_tariff_update', items: ['1.30'], attempts: 3),
      )
    end
  end

  describe '.delivery_failed' do
    it 'emits delivery_failed with the pipeline, identifier, notification uuid and status' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      described_class.delivery_failed(pipeline: 'customs_tariff_update', identifier: '1.30', notification_uuid: 'abc-123', status: 'permanent-failure')
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'delivery_failed.notifications',
        hash_including(pipeline: 'customs_tariff_update', identifier: '1.30', notification_uuid: 'abc-123', status: 'permanent-failure'),
      )
    end
  end
end

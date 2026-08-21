RSpec.describe Notifications::Logger do
  let(:log_subscriber) { described_class.new }

  def build_event(event_name, payload: {}, duration: 0.0)
    ActiveSupport::Notifications::Event.new(
      "#{event_name}.notifications",
      Time.current - (duration / 1000.0),
      Time.current,
      SecureRandom.hex(5),
      payload,
    )
  end

  describe '#send_skipped' do
    it 'logs the pipeline, identifier and reason at error level' do
      allow(log_subscriber).to receive(:error)

      log_subscriber.send_skipped(build_event('send_skipped', payload: { pipeline: 'customs_tariff_update', identifier: '1.30', reason: 'recipient_not_configured' }))

      expect(log_subscriber).to have_received(:error) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('event' => 'send_skipped', 'pipeline' => 'customs_tariff_update', 'identifier' => '1.30', 'reason' => 'recipient_not_configured')
      end
    end
  end

  describe '#enqueue_retrying' do
    it 'logs the pipeline, item, attempt and error details at error level' do
      allow(log_subscriber).to receive(:error)

      log_subscriber.enqueue_retrying(build_event('enqueue_retrying', payload: { pipeline: 'customs_tariff_update', item: '1.30', attempt: 1, error_class: 'RuntimeError', error_message: 'boom' }))

      expect(log_subscriber).to have_received(:error) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('event' => 'enqueue_retrying', 'pipeline' => 'customs_tariff_update', 'item' => '1.30', 'attempt' => 1, 'error_class' => 'RuntimeError', 'error_message' => 'boom')
      end
    end
  end

  describe '#enqueue_failed' do
    it 'logs the pipeline, items and attempts at error level' do
      allow(log_subscriber).to receive(:error)

      log_subscriber.enqueue_failed(build_event('enqueue_failed', payload: { pipeline: 'customs_tariff_update', items: ['1.30'], attempts: 3 }))

      expect(log_subscriber).to have_received(:error) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('event' => 'enqueue_failed', 'pipeline' => 'customs_tariff_update', 'items' => ['1.30'], 'attempts' => 3)
      end
    end
  end

  describe '#delivery_failed' do
    it 'logs the pipeline, identifier, notification uuid and status at error level' do
      allow(log_subscriber).to receive(:error)

      log_subscriber.delivery_failed(build_event('delivery_failed', payload: { pipeline: 'customs_tariff_update', identifier: '1.30', notification_uuid: 'abc-123', status: 'permanent-failure' }))

      expect(log_subscriber).to have_received(:error) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('event' => 'delivery_failed', 'pipeline' => 'customs_tariff_update', 'identifier' => '1.30', 'notification_uuid' => 'abc-123', 'status' => 'permanent-failure')
      end
    end
  end
end

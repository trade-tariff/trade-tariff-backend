RSpec.describe EnquiryForm::NotificationStatusCheckWorker, type: :worker do
  let(:checker) { instance_double(Notifications::DeliveryStatusChecker, call: status) }
  let(:status) { 'delivered' }

  before do
    allow(Notifications::DeliveryStatusChecker).to receive(:new).and_return(checker)
    allow(described_class).to receive(:perform_in)
  end

  it 'checks final delivery with a non-PII per-audience identifier' do
    described_class.new.perform('ABC12345', 'trade_tariff', 'notification-uuid')

    expect(Notifications::DeliveryStatusChecker).to have_received(:new).with(
      'notification-uuid',
      pipeline: 'enquiry_form',
      identifier: 'ABC12345:trade_tariff',
    )
    expect(checker).to have_received(:call)
  end

  context 'when Notify is still sending the email' do
    let(:status) { 'sending' }

    it 'schedules another bounded status check' do
      described_class.new.perform('ABC12345', 'trade_tariff', 'notification-uuid', 1)

      expect(described_class).to have_received(:perform_in).with(
        described_class::CHECK_INTERVAL,
        'ABC12345',
        'trade_tariff',
        'notification-uuid',
        2,
      )
    end

    it 'raises after the last bounded check so Sidekiq monitoring retains visibility' do
      expect {
        described_class.new.perform(
          'ABC12345',
          'trade_tariff',
          'notification-uuid',
          described_class::MAX_CHECKS,
        )
      }.to raise_error(EnquiryForm::NotificationStatusCheckWorker::PendingDeliveryError)
    end
  end
end

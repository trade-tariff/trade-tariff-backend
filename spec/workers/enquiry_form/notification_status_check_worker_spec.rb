RSpec.describe EnquiryForm::NotificationStatusCheckWorker, type: :worker do
  it 'checks final delivery with a non-PII per-audience identifier' do
    checker = instance_double(Notifications::DeliveryStatusChecker, call: nil)
    allow(Notifications::DeliveryStatusChecker).to receive(:new).and_return(checker)

    described_class.new.perform('ABC12345', 'trade_tariff', 'notification-uuid')

    expect(Notifications::DeliveryStatusChecker).to have_received(:new).with(
      'notification-uuid',
      pipeline: 'enquiry_form',
      identifier: 'ABC12345:trade_tariff',
    )
    expect(checker).to have_received(:call)
  end
end

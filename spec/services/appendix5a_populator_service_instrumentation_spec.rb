require 'spec_helper'

require 'action_mailer'
require 'logger'
require 'mail'

require_relative '../../app/services/appendix_5a_populator_service'

RSpec.describe Appendix5aPopulatorService do
  subject(:call) { service.call }

  before do
    stub_const('TestDatabase', Class.new do
      def transaction; end
    end)
    stub_const('TestDeliveryHandler', Class.new)
    stub_const('TestDeliveryMethod', Class.new)
    stub_const('TestGuidanceRecord', Class.new do
      def save; end
    end)
    stub_const('SlackNotifierService', Class.new do
      def self.call(_message); end
    end)
    stub_const('Appendix5aMailer', Class.new do
      def self.appendix5a_notify_message(_new_count, _changed_count, _removed_count); end
    end)
    stub_const('Rails', double(logger: logger))
    stub_const('Appendix5a', Class.new do
      class << self
        attr_accessor :db

        def unrestrict_primary_key; end

        def restrict_primary_key; end
      end
    end)
    Appendix5a.db = db

    allow(SlackNotifierService).to receive(:call).and_return(true)
    allow(Appendix5aMailer).to receive(:appendix5a_notify_message).and_return(message_delivery)
    allow(service).to receive_messages(
      added_guidance: [instance_double(TestGuidanceRecord, save: true)],
      changed_guidance: [],
      removed_guidance: [],
    )
    allow(mail_message).to receive(:instance_variable_get).with(:@smtp_envelope_to).and_return(nil)
  end

  let(:service) { described_class.new }
  let(:logger) { instance_spy(Logger) }
  let(:db) { instance_double(TestDatabase, transaction: true) }
  let(:message_delivery) { instance_double(ActionMailer::MessageDelivery, message: mail_message, deliver_now: true) }
  let(:mail_message) do
    instance_double(
      Mail::Message,
      to: ['cupid@example.com'],
      smtp_envelope_to: ['cupid@example.com'],
      delivery_handler: instance_double(TestDeliveryHandler, class: double(name: 'Appendix5aMailer')),
      delivery_method: instance_double(TestDeliveryMethod, class: double(name: 'Aws::ActionMailer::SESV2::Mailer')),
    )
  end

  it 'logs mail delivery state before delivery' do
    call

    expect(logger).to have_received(:info).with(include('Appendix5a mail delivery before_deliver'))
    expect(message_delivery).to have_received(:deliver_now)
  end

  context 'when the mail delivery raises an error' do
    let(:delivery_error) { ArgumentError.new('expected params[:destination][:to_addresses] to be an Array') }

    before do
      allow(message_delivery).to receive(:deliver_now).and_raise(delivery_error)
      allow(mail_message).to receive(:instance_variable_get).with(:@smtp_envelope_to).and_return('cupid@example.com')
    end

    it 'logs the failed delivery state and re-raises the original exception' do
      expect { call }.to raise_error(delivery_error)

      expect(logger).to have_received(:error).with(include('Appendix5a mail delivery deliver_failed'))
    end
  end
end

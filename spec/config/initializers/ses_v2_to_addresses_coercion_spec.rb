# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ses_v2_to_addresses_coercion initializer' do # rubocop:disable RSpec/DescribeClass
  # The mail gem normalises a single-recipient To: header to a plain String.
  # The SES v2 delivery method passes message.to directly to the AWS SDK,
  # which requires an Array. This spec verifies that the prepended module
  # always coerces the return value to an Array.
  describe 'Aws::ActionMailer::SESV2::Mailer#to_addresses' do
    subject(:mailer) { Aws::ActionMailer::SESV2::Mailer.new }

    def build_message(to:)
      mail_double = instance_double(Mail::Message, to:)
      allow(mail_double).to receive(:instance_variable_get).with(:@smtp_envelope_to).and_return(nil)
      mail_double
    end

    context 'when message.to is a String (single recipient, mail gem normalisation)' do
      it 'returns an Array' do
        message = build_message(to: 'single@example.com')
        result = mailer.send(:to_addresses, message)
        expect(result).to eq(['single@example.com'])
      end
    end

    context 'when message.to is already an Array (multiple recipients)' do
      it 'returns the Array unchanged' do
        message = build_message(to: ['a@example.com', 'b@example.com'])
        result = mailer.send(:to_addresses, message)
        expect(result).to eq(['a@example.com', 'b@example.com'])
      end
    end

    context 'when message.to is nil' do
      it 'returns an empty Array' do
        message = build_message(to: nil)
        result = mailer.send(:to_addresses, message)
        expect(result).to eq([])
      end
    end
  end
end

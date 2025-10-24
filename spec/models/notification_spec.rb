RSpec.describe Notification do
  describe 'validations' do
    subject { described_class.new(attributes).tap(&:valid?) }

    let(:attributes) do
      {
        email: 'foo@bar.com',
        template_id: 'b0f0c2b2-c5f5-4f3a-8d9c-f4c8e8ea1a7c',
        email_reply_to_id: 'f47ac10b-58cc-4372-a567-0e02b2c3d479',
        reference: 'REF123',
        personalisation: { name: 'John', age: 30, subscribed: true, victory: nil },
      }
    end

    it { is_expected.to be_valid }

    context 'when there are validation errors' do
      shared_examples 'invalid notification' do |attr, message, invalid_value|
        before { attributes[attr] = invalid_value }

        it "is invalid when #{attr} is #{invalid_value}" do
          expect(subject.errors[attr]).to include(message)
        end
      end

      include_examples 'invalid notification', :email, 'must be a valid e-mail address', 'invalid-email'
      include_examples 'invalid notification', :template_id, 'must be a valid UUID', 'invalid-uuid'
      include_examples 'invalid notification', :email_reply_to_id, 'must be a valid UUID', 'invalid-uuid'
      include_examples 'invalid notification', :reference, 'is too long (maximum is 255 characters)', 'A' * 256
      include_examples 'invalid notification', :personalisation, 'values must be scalar (String, Numeric, Boolean, nil)', { name: %w[array] }
    end
  end

  describe '#id' do
    subject { described_class.new.id }

    it { is_expected.to be_a_uuid }
  end

  describe '#as_json' do
    subject { described_class.new(attributes).as_json }

    let(:attributes) do
      {
        email: 'foo@bar.com',
        template_id: 'b0f0c2b2-c5f5-4f3a-8d9c-f4c8e8ea1a7c',
        email_reply_to_id: 'f47ac10b-58cc-4372-a567-0e02b2c3d479',
        reference: 'REF123',
        personalisation: { name: 'John', age: 30, subscribed: true, victory: nil },
      }
    end

    it { is_expected.to eq(attributes.deep_stringify_keys) }
  end
end

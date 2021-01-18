require 'rails_helper'

describe TradeTariffBackend::Validations::PresenceValidation do
  describe '#valid?' do
    let(:record) { double(a: 'a', b: 'b', c: nil).as_null_object }

    context 'all arguments are present on record' do
      let(:validation) do
        described_class.new(:vld1, 'valid', validation_options: { of: %i[a b] })
      end

      it 'returns true' do
        expect(
          validation.valid?(record),
        ).to be_truthy
      end
    end

    context 'some arguments are present on record' do
      let(:validation) do
        described_class.new(:vld1, 'valid', validation_options: { of: %i[a b c] })
      end

      it 'returns false' do
        expect(
          validation.valid?(record),
        ).to be_falsy
      end
    end
  end
end

require 'rails_helper'

describe TradeTariffBackend::Validations::ExclusionValidation do
  describe '#valid?' do
    context 'argument is an Array' do
      let(:model) { double(attr: :c) }
      let(:validation) do
        described_class.new(:vld1, 'valid', validation_options: { of: :attr,
                                                                  from: %i[a b c] })
      end

      it 'validates' do
        expect(validation.valid?(model)).to be_falsy
      end
    end

    context 'argument is a Proc' do
      let(:model) { double(attr: :c) }
      let(:validation) do
        described_class.new(:vld1, 'valid', validation_options: { of: :attr,
                                                                  from: -> { %i[a b c] } })
      end

      it 'validates' do
        expect(validation.valid?(model)).to be_falsy
      end
    end

    context 'no valid argument to check for povided' do
      let(:record) { double }
      let(:validation) do
        described_class.new(:vld1, 'valid', validation_options: { in: :attr })
      end

      it 'raises ArgumentError' do
        expect { validation.valid?(record) }.to raise_error ArgumentError
      end
    end
  end
end

RSpec.describe Currency do
  subject(:instance) { described_class.new monetary_unit }

  let(:monetary_unit) { 'EUR' }
  let(:duty_amount) { '123' }

  describe '#format' do
    context 'when monetary unit code is present in the hash' do
      it 'returns the the duty amount with currency symbol ' do
        expect(instance.format(duty_amount)).to eq('€123')
      end
    end

    context 'when monetary unit code is not present in the hash' do
      subject(:instance) { described_class.new 'XEM' }

      it 'returns empty string' do
        expect(instance.format(duty_amount)).to eq('123 XEM')
      end
    end
  end
end

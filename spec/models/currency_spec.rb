RSpec.describe Currency do
  subject(:instance) { described_class.new monetary_unit }

  let(:monetary_unit) { 'EUR' }
  let(:duty_amount) { '123' }

  describe '#format' do
    it 'returns the the duty amount with currency symbol ' do
      expect(instance.format(duty_amount)).to eq('€123')
    end
  end
end

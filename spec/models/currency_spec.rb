RSpec.describe Currency do
  let(:monetary_unit) { 'EUR' }
  let(:duty_amount) { 123 }

  describe '#to_symbol' do
    it 'returns the the duty amount with currency symbol ' do
      expect(described_class.to_symbol(monetary_unit, duty_amount)).to eq('€123')
    end
  end
end

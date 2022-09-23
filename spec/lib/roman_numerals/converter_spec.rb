RSpec.describe RomanNumerals::Converter do
  subject(:converter) { described_class }

  base_digits = {
    1 => 'I',
    4 => 'IV',
    5 => 'V',
    9 => 'IX',
    10 => 'X',
    40 => 'XL',
    50 => 'L',
    90 => 'XC',
    100 => 'C',
    400 => 'CD',
    500 => 'D',
    900 => 'CM',
    1000 => 'M',
  }

  describe '.to_decimal' do
    base_digits.each do |decimal, roman|
      it "converts the roman value #{roman} to the decimal value #{decimal}" do
        expect(converter.to_decimal(roman)).to eq(decimal)
      end
    end

    it 'converts larger roman numerals' do
      expect(converter.to_decimal('MMMCCXXXIV')).to eq(3234)
    end

    context 'when numerals is lower-case' do
      it { expect(converter.to_decimal('xlii')).to eq(42) }
    end

    context 'when numerals is already decimal' do
      it { expect(converter.to_decimal('12')).to eq(12) }
    end
  end
end

RSpec.describe TradeTariffBackend::NumberFormatter do
  let(:number_formatter) { described_class.new }

  describe '#number_with_precision' do
    context 'with minimum_decimal_points option' do
      it 'adds leading zero decimal numbers up to specified count' do
        expect(number_formatter.number_with_precision(1.2, minimum_decimal_points: 4)).to eq '1.2000'
        expect(number_formatter.number_with_precision(1, minimum_decimal_points: 4)).to eq '1.0000'
        expect(number_formatter.number_with_precision(1.23, minimum_decimal_points: 4)).to eq '1.2300'
      end

      context 'with precision specified' do
        it 'rounds to specified precision and adds leading decimal numbers if needed' do
          expect(
            number_formatter.number_with_precision(
              1.256,
              minimum_decimal_points: 2,
              precision: 1,
            ),
          ).to eq '1.30'
        end
      end

      context 'with stripping of insignificant zeros enabled' do
        it 'strips insignificant zeroes up to minimum decimal points size' do
          expect(
            number_formatter.number_with_precision(
              1.256,
              minimum_decimal_points: 2,
              precision: 1,
              strip_insignificant_zeroes: true,
            ),
          ).to eq '1.30'

          expect(
            number_formatter.number_with_precision(
              1.25656,
              minimum_decimal_points: 4,
              precision: 3,
              strip_insignificant_zeroes: true,
            ),
          ).to eq '1.2570'
        end
      end
    end
  end
end

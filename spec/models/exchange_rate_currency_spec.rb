RSpec.describe ExchangeRateCurrency do
  let(:worksheet) { double('worksheet') }
  let(:workbook) { double('workbook', sheet: worksheet) }
  let(:exchange_rate_currency1) { build(:exchange_rate_currency) }
  let(:exchange_rate_currency2) { build(:exchange_rate_currency, currency_code: 'CAD', currency_description: 'Dollar', spot_rate_required: true) }

  before do
    allow(Roo::Spreadsheet).to receive(:open).with('data/exchange_rates/currency-master-data-set.xlsx').and_return(workbook)
  end

  describe '.populate' do
    it 'populates ExchangeRateCurrency records from the spreadsheet' do
      allow(worksheet).to receive(:each_row_streaming).and_yield(exchange_rate_currency1.instance_variable_get(:@values).values).and_yield(exchange_rate_currency2.instance_variable_get(:@values).values)

      expect(described_class).to receive(:unrestrict_primary_key)

      expect(described_class).to receive(:create).with(
        currency_code: 'AED',
        currency_description: 'Dirham',
        spot_rate_required: false,
      )

      expect(described_class).to receive(:create).with(exchange_rate_currency2.instance_variable_get(:@values))
      expect(described_class).to receive(:restrict_primary_key)

      described_class.populate
    end
  end
end

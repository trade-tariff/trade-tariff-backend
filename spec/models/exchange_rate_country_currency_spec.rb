RSpec.describe ExchangeRateCountryCurrency do



  describe '.live_currency_codes' do
    before do
      create(:exchange_rate_country_currency)
    end

    it 'retuns all the live currency_codes' do
      expect(described_class.live_currency_codes).to eq(['EUR'])
    end
  end
end

RSpec.describe ExchangeRateCountryCurrency do
  describe '.live_currency_codes' do
    before do
      create(:exchange_rate_country_currency, :eu)
      create(:exchange_rate_country_currency, :kz,
             validity_end_date: Time.zone.today.end_of_month - 1.month)
    end

    it 'retuns all the live currency_codes' do
      expect(described_class.live_currency_codes).to eq(%w[EUR])
    end
  end

  describe '.live_countries' do
    before do
      create(:exchange_rate_country_currency, :eu)
      create(:exchange_rate_country_currency, :kz,
             validity_end_date: Time.zone.today.end_of_month - 1.month)
    end

    it 'retuns all the live currency_codes', :aggregate_failures do
      expect(described_class.live_countries.count).to eq(1)
      expect(described_class.live_countries.pluck(:country_code)).to eq(%w[EU])
      expect(described_class.live_countries.pluck(:country_description)).to eq(%w[Eurozone])
    end
  end
end

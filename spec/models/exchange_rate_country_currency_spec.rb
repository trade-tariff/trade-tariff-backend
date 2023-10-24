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

  describe '.live_last_twelve_months' do
    before do
      # ======= Live Countries last 12 months =======

      # Since 2020
      create(:exchange_rate_country_currency, :eu)
      # Starts end of the month
      create(:exchange_rate_country_currency, :kz,
             validity_start_date: Time.zone.today.end_of_month)
      # Ended beginning of current month minus 11 months
      create(:exchange_rate_country_currency, :zw,
             validity_end_date: Time.zone.today.beginning_of_month - 11.months)

      # ======= Not live last 12 months =======

      # Live beginning next Month
      create(:exchange_rate_country_currency, :bd,
             validity_start_date: Time.zone.today.beginning_of_month + 1.month)
      # Ended beginning of current month - 12 months ago - 1 day
      create(:exchange_rate_country_currency, :du,
             validity_end_date: Time.zone.today.end_of_month - 12.months)
    end

    it 'retuns all the live currency_codes', :aggregate_failures do
      expect(described_class.live_last_twelve_months.count).to eq(3)
      expect(described_class.live_last_twelve_months.pluck(:country_code)).to eq(%w[EU KZ ZW])
    end
  end
end

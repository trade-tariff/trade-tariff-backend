RSpec.describe Api::V2::ExchangeRates::CurrencyRatePresenter do
  subject(:presenter) { described_class.new(exchange_rate_currency_rate, month, year) }

  let(:exchange_rate_currency_rate) { build(:exchange_rate_currency_rate) }
  let(:month) { 6 }
  let(:year) { 2023 }

  it { is_expected.to respond_to(:month) }
  it { is_expected.to respond_to(:year) }

  describe '#id' do
    let(:exchange_rate_currency_rate) { build(:exchange_rate_currency_rate, currency_code: 'GBP') }

    it 'returns the formatted exchange_rate_currency_rate ID' do
      expect(presenter.id).to eq('2023-6-GBP-currency-rate')
    end
  end

  describe '#exchange_rate_country_ids' do
    before { create(:exchange_rate_country, country_code: 'UK', currency_code: 'GBP') }

    let(:exchange_rate_currency_rate) do
      create(:exchange_rate_currency_rate, currency_code: 'GBP')
    end

    it 'returns the exchange_rate_country IDs' do
      expect(presenter.exchange_rate_country_ids).to eq(%w[UK])
    end
  end
end

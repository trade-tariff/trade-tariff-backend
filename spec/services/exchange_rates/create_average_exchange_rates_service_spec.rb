RSpec.describe ExchangeRates::CreateAverageExchangeRatesService do
  describe '.call' do
    subject(:create_average_rates) { described_class.call(force_run:, selected_date: test_date) }

    let(:force_run) { false }
    let(:parsed_date) { Date.parse(test_date) }

    let(:expected_filepath) { "data/exchange_rates/#{parsed_date.year}/#{parsed_date.month}/average_csv_#{parsed_date.year}-#{parsed_date.month}.csv" }
    let(:expected_csv) do
      <<~CSV
        Country,Unit Of Currency,Currency Code,Sterling value of Currency Unit £,Currency Units per £1
        Eurozone,Euro,EUR,0.8702,1.1492
        Kazakhstan,Dollar,USD,0.8154,1.2264
        United States,Dollar,USD,0.8154,1.2264
      CSV
    end

    before do
      travel_to parsed_date
      setup_data

      allow(TariffSynchronizer::FileService)
       .to receive(:write_file)
       .with(expected_filepath, expected_csv)
      allow(TariffSynchronizer::FileService).to receive(:file_size).and_return(1)
    end

    shared_examples 'creating the average rates' do
      it 'creates the average rates', :aggregate_failures do
        create_average_rates

        avg_rates = ExchangeRateCurrencyRate.by_type(ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE)

        expect(avg_rates.count).to eq(2)
        expect(avg_rates.all? { |r| r.validity_start_date == Time.zone.today.beginning_of_month - 11.months }).to be true
        expect(avg_rates.all? { |r| r.validity_end_date == Time.zone.today.end_of_month }).to be true

        expect(avg_rates.by_currency('USD').first.rate).to eq(1.2264056116916666)
        expect(avg_rates.by_currency('EUR').first.rate).to eq(1.1491571170166666)
        expect(TariffSynchronizer::FileService).to have_received(:write_file).with(expected_filepath, expected_csv)
      end
    end

    context 'when run on a valid date' do
      let(:test_date) { '2023-12-31' }

      after do
        travel_back
      end

      it_behaves_like 'creating the average rates'
    end

    context 'when run on an invalid date' do
      let(:test_date) { '2023-10-25' }

      after do
        travel_back
      end

      it 'returns an argument error' do
        expect { create_average_rates }.to raise_error(ArgumentError)
      end

      context 'with force run enabled' do
        let(:force_run) { true }

        it_behaves_like 'creating the average rates'
      end
    end
  end

  def setup_data
    # 13 months of data 1 in the future for US
    us = create(:exchange_rate_country_currency, :us)

    # 12 months of data for EU
    eu = create(:exchange_rate_country_currency, :eu)

    # Last 5 months of data with AU
    au = create(:exchange_rate_country_currency, :au)

    # First 3 months of data for DU
    du = create(:exchange_rate_country_currency, :du)

    # First 6 months in Tenge
    kz = create(:exchange_rate_country_currency, :kz,
                validity_start_date: Time.zone.today.beginning_of_month - 11.months,
                validity_end_date: Time.zone.today.end_of_month - 6.months)

    # last 2 months in USD
    # This would count as the valid currency to produce the avg for USD
    create(:exchange_rate_country_currency, :kz,
           currency_code: us.currency_code,
           currency_description: us.currency_description,
           validity_start_date: Time.zone.today.beginning_of_month - 1.month)

    # Middle 4 months in EUR
    create(:exchange_rate_country_currency, :kz,
           currency_code: eu.currency_code,
           currency_description: eu.currency_description,
           validity_start_date: Time.zone.today.beginning_of_month - 5.months,
           validity_end_date: Time.zone.today.end_of_month - 2.months)

    # Older than 12 months
    zw = create(:exchange_rate_country_currency, :zw,
                validity_start_date: Time.zone.today.beginning_of_month - 13.months,
                validity_end_date: Time.zone.today.end_of_month - 12.months)

    # Not valid till next month
    bd = create(:exchange_rate_country_currency, :bd,
                validity_start_date: Time.zone.today.beginning_of_month + 1.month,
                validity_end_date: Time.zone.today.end_of_month + 1.month)

    # BD
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: bd.currency_code,
           rate: 2.5678,
           validity_start_date: Time.zone.today.beginning_of_month + 1.month,
           validity_end_date: Time.zone.today.end_of_month + 1.month)

    # ZW
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: zw.currency_code,
           rate: 447.5529925241,
           validity_start_date: Time.zone.today.beginning_of_month - 12.months,
           validity_end_date: Time.zone.today.end_of_month - 12.months)

    # KZ
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: kz.currency_code,
           rate: 560.7196,
           validity_start_date: Time.zone.today.beginning_of_month,
           validity_end_date: Time.zone.today.end_of_month)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: kz.currency_code,
           rate: 529.4648,
           validity_start_date: Time.zone.today.beginning_of_month - 1.month,
           validity_end_date: Time.zone.today.end_of_month - 1.month)

    # US 13 months including next months avg rate
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: us.currency_code,
           rate: 1.2366758567,
           validity_start_date: Time.zone.today.beginning_of_month + 1.month,
           validity_end_date: Time.zone.today.end_of_month + 1.month)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: us.currency_code,
           rate: 1.2630673403,
           validity_start_date: Time.zone.today.beginning_of_month,
           validity_end_date: Time.zone.today.end_of_month)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: us.currency_code,
           rate: 1.2886,
           validity_start_date: Time.zone.today.beginning_of_month - 1.month,
           validity_end_date: Time.zone.today.end_of_month - 1.month)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: us.currency_code,
           rate: 1.2732,
           validity_start_date: Time.zone.today.beginning_of_month - 2.months,
           validity_end_date: Time.zone.today.end_of_month - 2.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: us.currency_code,
           rate: 1.2366,
           validity_start_date: Time.zone.today.beginning_of_month - 3.months,
           validity_end_date: Time.zone.today.end_of_month - 3.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: us.currency_code,
           rate: 1.245,
           validity_start_date: Time.zone.today.beginning_of_month - 4.months,
           validity_end_date: Time.zone.today.end_of_month - 4.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: us.currency_code,
           rate: 1.2231,
           validity_start_date: Time.zone.today.beginning_of_month - 5.months,
           validity_end_date: Time.zone.today.end_of_month - 5.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: us.currency_code,
           rate: 1.2002,
           validity_start_date: Time.zone.today.beginning_of_month - 6.months,
           validity_end_date: Time.zone.today.end_of_month - 6.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: us.currency_code,
           rate: 1.2392,
           validity_start_date: Time.zone.today.beginning_of_month - 7.months,
           validity_end_date: Time.zone.today.end_of_month - 7.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: us.currency_code,
           rate: 1.2406,
           validity_start_date: Time.zone.today.beginning_of_month - 8.months,
           validity_end_date: Time.zone.today.end_of_month - 8.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: us.currency_code,
           rate: 1.2065,
           validity_start_date: Time.zone.today.beginning_of_month - 9.months,
           validity_end_date: Time.zone.today.end_of_month - 9.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: us.currency_code,
           rate: 1.1259,
           validity_start_date: Time.zone.today.beginning_of_month - 10.months,
           validity_end_date: Time.zone.today.end_of_month - 10.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: us.currency_code,
           rate: 1.1749,
           validity_start_date: Time.zone.today.beginning_of_month - 11.months,
           validity_end_date: Time.zone.today.end_of_month - 11.months)

    # EU 12 months only
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: eu.currency_code,
           rate: 1.1682854042,
           validity_start_date: Time.zone.today.beginning_of_month,
           validity_end_date: Time.zone.today.end_of_month)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: eu.currency_code,
           rate: 1.1515,
           validity_start_date: Time.zone.today.beginning_of_month - 1.month,
           validity_end_date: Time.zone.today.end_of_month - 1.month)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: eu.currency_code,
           rate: 1.1622,
           validity_start_date: Time.zone.today.beginning_of_month - 2.months,
           validity_end_date: Time.zone.today.end_of_month - 2.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: eu.currency_code,
           rate: 1.1489,
           validity_start_date: Time.zone.today.beginning_of_month - 3.months,
           validity_end_date: Time.zone.today.end_of_month - 3.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: eu.currency_code,
           rate: 1.1361,
           validity_start_date: Time.zone.today.beginning_of_month - 4.months,
           validity_end_date: Time.zone.today.end_of_month - 4.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: eu.currency_code,
           rate: 1.1334,
           validity_start_date: Time.zone.today.beginning_of_month - 5.months,
           validity_end_date: Time.zone.today.end_of_month - 5.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: eu.currency_code,
           rate: 1.1242,
           validity_start_date: Time.zone.today.beginning_of_month - 6.months,
           validity_end_date: Time.zone.today.end_of_month - 6.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: eu.currency_code,
           rate: 1.1441,
           validity_start_date: Time.zone.today.beginning_of_month - 7.months,
           validity_end_date: Time.zone.today.end_of_month - 7.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: eu.currency_code,
           rate: 1.1652,
           validity_start_date: Time.zone.today.beginning_of_month - 8.months,
           validity_end_date: Time.zone.today.end_of_month - 8.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: eu.currency_code,
           rate: 1.163,
           validity_start_date: Time.zone.today.beginning_of_month - 9.months,
           validity_end_date: Time.zone.today.end_of_month - 9.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: eu.currency_code,
           rate: 1.15,
           validity_start_date: Time.zone.today.beginning_of_month - 10.months,
           validity_end_date: Time.zone.today.end_of_month - 10.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: eu.currency_code,
           rate: 1.143,
           validity_start_date: Time.zone.today.beginning_of_month - 11.months,
           validity_end_date: Time.zone.today.end_of_month - 11.months)

    # AU Last 5 months only
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: au.currency_code,
           rate: 1.9676556304,
           validity_start_date: Time.zone.today.beginning_of_month,
           validity_end_date: Time.zone.today.end_of_month)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: au.currency_code,
           rate: 1.907,
           validity_start_date: Time.zone.today.beginning_of_month - 1.month,
           validity_end_date: Time.zone.today.end_of_month - 1.month)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: au.currency_code,
           rate: 1.8804,
           validity_start_date: Time.zone.today.beginning_of_month - 2.months,
           validity_end_date: Time.zone.today.end_of_month - 2.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: au.currency_code,
           rate: 1.8915,
           validity_start_date: Time.zone.today.beginning_of_month - 3.months,
           validity_end_date: Time.zone.today.end_of_month - 3.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: au.currency_code,
           rate: 1.852,
           validity_start_date: Time.zone.today.beginning_of_month - 4.months,
           validity_end_date: Time.zone.today.end_of_month - 4.months)

    # DU First 3 months
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: du.currency_code,
           rate: 4.5569,
           validity_start_date: Time.zone.today.beginning_of_month - 9.months,
           validity_end_date: Time.zone.today.end_of_month - 9.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: du.currency_code,
           rate: 4.4317,
           validity_start_date: Time.zone.today.beginning_of_month - 10.months,
           validity_end_date: Time.zone.today.end_of_month - 10.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: du.currency_code,
           rate: 4.1355,
           validity_start_date: Time.zone.today.beginning_of_month - 11.months,
           validity_end_date: Time.zone.today.end_of_month - 11.months)
  end
end

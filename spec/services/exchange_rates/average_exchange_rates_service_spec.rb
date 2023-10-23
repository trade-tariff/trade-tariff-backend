require 'rails_helper'

RSpec.describe ExchangeRates::AverageExchangeRatesService do
  describe '.call' do
    subject(:create_average_rates) { described_class.call }

    before do
      setup_standard_data
    end

    context 'when run on a valid date' do
      # This is when we 12 months exactly for particular currencies and countries
      context 'with 12 months only of data' do
        it 'creates the average rates' do
          create_average_rates
        end
      end
    end

    context 'when run on an invalid date' do
      it 'will return some error' do
      end
    end
  end

  def setup_standard_data
    # Run for dec run
    # 12 full months including dec
    us = create(:exchange_rate_country_currency, :us)
    eu = create(:exchange_rate_country_currency, :eu)
    au = create(:exchange_rate_country_currency, :au)
    du = create(:exchange_rate_country_currency, :du)

    # Last 2 months only
    kz = create(:exchange_rate_country_currency, :kz)

    # Only one month in the middle but another currency has it
    create(:exchange_rate_country_currency, :dh)

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

    # US
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

    # EU
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: eu.currency_code,
           rate: 1.1555189008,
           validity_start_date: Time.zone.today.beginning_of_month + 1.month,
           validity_end_date: Time.zone.today.end_of_month + 1.month)
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

    # AU
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: au.currency_code,
           rate: 1.906730541,
           validity_start_date: Time.zone.today.beginning_of_month + 1.month,
           validity_end_date: Time.zone.today.end_of_month + 1.month)
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
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: au.currency_code,
           rate: 1.8295,
           validity_start_date: Time.zone.today.beginning_of_month - 5.months,
           validity_end_date: Time.zone.today.end_of_month - 5.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: au.currency_code,
           rate: 1.7446,
           validity_start_date: Time.zone.today.beginning_of_month - 6.months,
           validity_end_date: Time.zone.today.end_of_month - 6.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: au.currency_code,
           rate: 1.7679,
           validity_start_date: Time.zone.today.beginning_of_month - 7.months,
           validity_end_date: Time.zone.today.end_of_month - 7.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: au.currency_code,
           rate: 1.807,
           validity_start_date: Time.zone.today.beginning_of_month - 8.months,
           validity_end_date: Time.zone.today.end_of_month - 8.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: au.currency_code,
           rate: 1.7951,
           validity_start_date: Time.zone.today.beginning_of_month - 9.months,
           validity_end_date: Time.zone.today.end_of_month - 9.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: au.currency_code,
           rate: 1.7896,
           validity_start_date: Time.zone.today.beginning_of_month - 10.months,
           validity_end_date: Time.zone.today.end_of_month - 10.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: au.currency_code,
           rate: 1.7816,
           validity_start_date: Time.zone.today.beginning_of_month - 11.months,
           validity_end_date: Time.zone.today.end_of_month - 11.months)

    # DU
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: du.currency_code,
           rate: 4.5416920836,
           validity_start_date: Time.zone.today.beginning_of_month + 1.month,
           validity_end_date: Time.zone.today.end_of_month + 1.month)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: du.currency_code,
           rate: 4.6386148073,
           validity_start_date: Time.zone.today.beginning_of_month,
           validity_end_date: Time.zone.today.end_of_month)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: du.currency_code,
           rate: 4.7333,
           validity_start_date: Time.zone.today.beginning_of_month - 1.month,
           validity_end_date: Time.zone.today.end_of_month - 1.month)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: du.currency_code,
           rate: 4.6766,
           validity_start_date: Time.zone.today.beginning_of_month - 2.months,
           validity_end_date: Time.zone.today.end_of_month - 2.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: du.currency_code,
           rate: 4.5409,
           validity_start_date: Time.zone.today.beginning_of_month - 3.months,
           validity_end_date: Time.zone.today.end_of_month - 3.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: du.currency_code,
           rate: 4.5722,
           validity_start_date: Time.zone.today.beginning_of_month - 4.months,
           validity_end_date: Time.zone.today.end_of_month - 4.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: du.currency_code,
           rate: 4.4918,
           validity_start_date: Time.zone.today.beginning_of_month - 5.months,
           validity_end_date: Time.zone.today.end_of_month - 5.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: du.currency_code,
           rate: 4.4228,
           validity_start_date: Time.zone.today.beginning_of_month - 6.months,
           validity_end_date: Time.zone.today.end_of_month - 6.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: du.currency_code,
           rate: 4.4084,
           validity_start_date: Time.zone.today.beginning_of_month - 7.months,
           validity_end_date: Time.zone.today.end_of_month - 7.months)
    create(:exchange_rate_currency_rate,
           :monthly_rate,
           currency_code: du.currency_code,
           rate: 4.5516,
           validity_start_date: Time.zone.today.beginning_of_month - 8.months,
           validity_end_date: Time.zone.today.end_of_month - 8.months)
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

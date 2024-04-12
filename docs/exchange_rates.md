# Exchnage Rates

This page is designed to explain about exchange rates

## Emergency changelog

It has happened too often that data has had to be adjusted in the DB

15/02/2024 - Liberia rate has been displayed as wrong as the data given to us from HMRC. Checking the `20240118183459_fix_liberia_country_code.rb` file you can see that the existing rate was altered and ended in Oct 2023 and changed to be using USD as this is the rate we had inherited from HMRC. From Nov when we started pulling data from XE we started using the LRD rate. Also because of this we had to alter slightly the monthly files going back to the beginning using the avg rate rake tasks to remove the old rate and rebuild them. These are the two queries that were run: `MONTH_START_PERIOD=1 YEAR_START_PERIOD=2021 MONTH_END_PERIOD=10 YEAR_END_PERIOD=2023 CURRENCY_CODE=LRD bundle exec rake exchange_rates:rebuild_old_monthly_rates`
`AVG_PERIOD_MONTH=12 AVG_PERIOD_YEAR=2023 bundle exec rake exchange_rates:rebuild_average_rates`

## Average rates

Average rates are calculated based on the live countries in the last 12 months from the date selected in the `ExchangeRates::AverageExchangeRatesService` class. Normally the worker class `AverageExchangeRatesWorker` Will run on the 31st March and 31st Dec. It will select all the countries that have had a live rate for the last year through working out the end of the month date selected *(eg. if the service is run on the 12th May then it will use 31st May for that year going back to the 1st of June for the previous year hgathering all country and currency parings).* This solved the issue if a country might have multiple currencies in one year and we have to display the average for currencies that country has had even if its just one day.

You can then navigate to <https://www.trade-tariff.service.gov.uk/exchange_rates/average> and the latest data will be available to view online plus files.

You can check the exchange rates for the last year by running this command: `ExchangeRateCurrencyRate.by_type(ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE).where(validity_end_date: Date.new(2023,12,31)).all` Chnaging the date to the end of the period you are checking for (this example uses end of dec 2023)

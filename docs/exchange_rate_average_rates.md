# Exchange rates average rates

This page is designed to explain about average rates, how they are run and how to force running them should something go wrong.

Average rates are calculated based on the live countries in the last 12 months from the date selected in the `ExchangeRates::AverageExchangeRatesService` class. Normally the worker class `AverageExchangeRatesWorker` Will run on the 31st March and 31st Dec. It will select all the countries that have had a live rate for the last year through working out the end of the month date selected *(eg. if the service is run on the 12th May then it will use 31st May for that year going back to the 1st of June for the previous year hgathering all country and currency parings).* This solved the issue if a country might have multiple currencies in one year and we have to display the average for currencies that country has had even if its just one day.

## Force running the proces

Should anything fail with the average rate service then it can be force run by the following command:

`ExchangeRates::CreateAverageExchangeRatesService.call(force_run: true, selected_date: Time.zone.today.iso8601)`

You can then navigate to https://www.trade-tariff.service.gov.uk/exchange_rates/average and the latest CSV will be available to view online.

You can check the exchange rates for the last year by running this command: `ExchangeRateCurrencyRate.by_type(ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE)`

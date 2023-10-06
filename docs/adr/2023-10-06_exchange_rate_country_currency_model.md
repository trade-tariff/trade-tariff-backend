# Adding an exchange rates country currency concept

Date: 6 Oct 2023
Status: Accepted
Present: William Fish, Alessandro De Simone, Sam Johnson, Ata Dari, Chris Booth

## Context

We've built an exchange rate service which fetches rates from an api and stores them in
the exchange rate currency rates table.

To work out:

1. What currencies to import
2. What countries have what currencies at a given time

We have a currency and country table which associates exchange rates to currencies
via the currency_code key.

We need to support an exchange rate of any type having a country description, currency description
and currency/country association at a given point in time.

This is because:

1. Countries can change names over time
2. Countries can change currencies over time
3. Countries can have multiple currencies
4. Countries can split/merge into separate/larger countries

## Decision

We've decided to add an exchange_rate_countries_currencies table which will support our
ability to work out the associated names and currencies of a given country over time.

This means that multiple exchange rate country currencies can apply to the given exchange rates
window and we will take the most recent country description for a given exchange rate currency code
and exchange rate country code.

## Consequences

This is a more complex implementation and results in quite a bit more edge cases to consider.

For example:

- There's a burden to maintain country descriptions/currency descriptions and currency/country associations.
- We need to a lot more tests that need to be written to cover the complexity.

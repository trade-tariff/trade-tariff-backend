Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    swaziland = ExchangeRateCountryCurrency.find(
      country_code:         "SZ",
      country_description:  "Swaziland",
      validity_end_date:    nil,
    )

    if swaziland.present?
      swaziland.validity_end_date = Date.parse("2018-02-28")
      swaziland.save

      eswatini = ExchangeRateCountryCurrency.new(
        country_code:         "SZ",
        country_description:  "Eswatini",
        validity_start_date:  Date.parse("2018-03-01"),
        currency_code:        "SZL",
        currency_description: "Lilangeni",
      )
      eswatini.save
    end
  end

  down do
    eswatini = ExchangeRateCountryCurrency.find(
      country_code:         "SZ",
      country_description:  "Eswatini",
      validity_end_date:    nil,
    )

    swaziland = ExchangeRateCountryCurrency.find(
      country_code:         "SZ",
      country_description:  "Swaziland",
      validity_end_date:    Date.parse("2018-02-28")
    )

    if eswatini.present? && swaziland.present?
      swaziland.validity_end_date = nil
      eswatini.validity_end_date = Date.parse("2018-02-28")

      swaziland.save
      eswatini.save
    end
  end
end

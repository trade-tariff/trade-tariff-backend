Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    if TradeTariffBackend.uk?
      files_to_update = ExchangeRateFile.where(period_year: 2023, period_month: [10, 11, 12], type: ["monthly_csv_hmrc", "monthly_csv", "monthly_xml"])

      files_to_update.each do |file|
        new_publication_date =
          case file.period_month
          when 10
            Date.new(2023, 9, 20)
          when 11
            Date.new(2023, 10, 18)
          when 12
            Date.new(2023, 11, 22)
          end

        file.update(publication_date: new_publication_date)
      end

    end
  end

  down do
    # We don't want to rollback to incorrect dates.
  end
end

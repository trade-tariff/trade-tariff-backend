TradeTariffBackend::DataMigrator.migration do
  name 'Fixes missing validity_end_date for xi measure 3753097'

  up do
    applicable { false }

    apply do
      if TradeTariffBackend.xi?
        end_date = Time.zone.parse('2020-02-26')
        measure = Measure.where(measure_sid: 3_753_097).last

        return if measure.validity_end_date == end_date

        measure.update(validity_end_date: end_date)
        measure.save
      end
    end
  end

  down {}
end

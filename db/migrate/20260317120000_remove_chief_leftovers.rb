# frozen_string_literal: true

Sequel.migration do
  up do
    next if TradeTariffBackend.xi?

    chief_tables = %w[
      chief_comm
      chief_country_code
      chief_country_group
      chief_duty_expression
      chief_measure_type_adco
      chief_measure_type_cond
      chief_measure_type_footnote
      chief_measurement_unit
      chief_mfcm
      chief_tame
      chief_tamf
      chief_tbl9
    ]
    chief_sequences = %w[
      chief_duty_expression_id_seq
      chief_measure_type_footnote_id_seq
      chief_measurement_unit_id_seq
    ]
    tariff_updates_table = Sequel[:tariff_updates].qualify(:uk)

    if Sequel::Model.db.table_exists?(tariff_updates_table)
      from(tariff_updates_table)
        .where(update_type: 'TariffSynchronizer::ChiefUpdate')
        .delete
    end

    chief_tables.each do |table|
      run "DROP TABLE IF EXISTS uk.#{table} CASCADE"
    end

    chief_sequences.each do |sequence|
      run "DROP SEQUENCE IF EXISTS uk.#{sequence} CASCADE"
    end
  end

  down do
    raise Sequel::Error, 'remove_chief_leftovers is irreversible'
  end
end

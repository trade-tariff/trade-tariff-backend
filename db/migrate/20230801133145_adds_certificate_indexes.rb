Sequel.migration do
  up do
    alter_table :measure_conditions_oplog do
      add_index :certificate_type_code
    end

    run 'CREATE INDEX certificate_descriptions_description_trgm_idx ON certificate_descriptions_oplog USING GIST (description gist_trgm_ops);'
  end

  down do
    alter_table :measure_conditions_oplog do
      drop_index :certificate_type_code
    end

    run 'DROP INDEX certificate_descriptions_description_trgm_idx;'
  end
end

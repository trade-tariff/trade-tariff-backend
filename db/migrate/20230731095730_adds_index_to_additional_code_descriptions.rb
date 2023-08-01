Sequel.migration do
  up do
    run 'CREATE INDEX add_code_desc_description_trgm_idx ON additional_code_descriptions_oplog USING GIST (description gist_trgm_ops);'
  end

  down do
    run 'DROP INDEX add_code_desc_description_trgm_idx;'
  end
end

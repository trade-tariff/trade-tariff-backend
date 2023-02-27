Sequel.migration do
  up do
    run 'CREATE EXTENSION IF NOT EXISTS pg_trgm;'

    create_table :search_suggestions do
      String :id
      String :value
      DateTime :created_at
      DateTime :updated_at
      primary_key %i[id value]
    end

    run 'CREATE INDEX search_suggestions_value_trgm_idx ON search_suggestions USING GIST (value gist_trgm_ops);'
  end

  down do
    run 'DROP INDEX IF EXISTS search_suggestions_value_trgm_idx;'

    drop_table :search_suggestions

    run 'DROP EXTENSION IF EXISTS pg_trgm;'
  end
end

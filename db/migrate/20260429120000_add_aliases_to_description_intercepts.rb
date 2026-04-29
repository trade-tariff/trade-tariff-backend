Sequel.migration do
  up do
    alter_table :description_intercepts do
      add_column :aliases, 'text[]', null: false, default: Sequel.pg_array([], :text)
    end

    run 'CREATE INDEX idx_description_intercepts_aliases_gin ON description_intercepts USING gin (aliases)'
  end

  down do
    run 'DROP INDEX IF EXISTS idx_description_intercepts_aliases_gin'

    alter_table :description_intercepts do
      drop_column :aliases
    end
  end
end

Sequel.migration do
  up do
    create_table :description_intercepts do
      primary_key :id
      String :term, null: false
      column :sources, 'text[]', null: false, default: Sequel.pg_array([], :text)
      String :message, text: true
      TrueClass :excluded, null: false, default: false
      DateTime :created_at, null: false, default: Sequel.lit('CURRENT_TIMESTAMP')
      DateTime :updated_at, null: false, default: Sequel.lit('CURRENT_TIMESTAMP')

      index :term
      index :excluded
    end

    run 'CREATE INDEX idx_description_intercepts_sources_gin ON description_intercepts USING gin (sources)'
  end

  down do
    drop_table :description_intercepts
  end
end

# frozen_string_literal: true

Sequel.migration do
  up do
    run <<-SQL
      CREATE INDEX IF NOT EXISTS idx_search_suggestions_value_trgm
        ON search_suggestions USING gin (value gin_trgm_ops);

      CREATE INDEX IF NOT EXISTS idx_search_suggestions_distinct
        ON search_suggestions (value, priority);
    SQL
  end

  down do
    run <<-SQL
      DROP INDEX IF EXISTS idx_search_suggestions_value_trgm;
      DROP INDEX IF EXISTS idx_search_suggestions_distinct;
    SQL
  end
end

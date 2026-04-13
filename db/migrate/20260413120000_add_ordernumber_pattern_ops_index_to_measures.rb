Sequel.migration do
  no_transaction

  up do
    execute "CREATE INDEX CONCURRENTLY IF NOT EXISTS measures_ordernumber_pattern_idx ON uk.measures (ordernumber varchar_pattern_ops)"
    execute "CREATE INDEX CONCURRENTLY IF NOT EXISTS measures_ordernumber_pattern_idx ON xi.measures (ordernumber varchar_pattern_ops)"
  end

  down do
    execute "DROP INDEX CONCURRENTLY IF EXISTS uk.measures_ordernumber_pattern_idx"
    execute "DROP INDEX CONCURRENTLY IF EXISTS xi.measures_ordernumber_pattern_idx"
  end
end

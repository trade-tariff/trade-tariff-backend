Sequel.migration do
  # Some deployed databases already have this table without atar_percentage.
  # Current code does not write the column, but a task from the previous
  # release still does. The column has to exist, with a default, before
  # either version inserts a row.
  up do
    next unless table_exists?(:evaluation_gold_query_sets)

    unless fetch(<<~SQL).any?
      SELECT 1
      FROM pg_attribute
      WHERE attrelid = 'evaluation_gold_query_sets'::regclass
        AND attname = 'atar_percentage'
        AND attnum > 0
        AND NOT attisdropped
    SQL
      alter_table(:evaluation_gold_query_sets) do
        add_column :atar_percentage, Integer, null: false, default: 100
      end
    end

    alter_table(:evaluation_gold_query_sets) do
      set_column_default :atar_percentage, 100
    end

    next if fetch(<<~SQL).any?
      SELECT 1
      FROM pg_constraint
      WHERE conrelid = 'evaluation_gold_query_sets'::regclass
        AND conname = 'evaluation_gold_query_sets_atar_percentage_check'
    SQL

    alter_table(:evaluation_gold_query_sets) do
      add_constraint(
        :evaluation_gold_query_sets_atar_percentage_check,
        Sequel.lit('atar_percentage BETWEEN 0 AND 100'),
      )
    end
  end

  down do
    next unless table_exists?(:evaluation_gold_query_sets)
    next unless fetch(<<~SQL).any?
      SELECT 1
      FROM pg_attribute
      WHERE attrelid = 'evaluation_gold_query_sets'::regclass
        AND attname = 'atar_percentage'
        AND attnum > 0
        AND NOT attisdropped
    SQL

    alter_table(:evaluation_gold_query_sets) do
      set_column_default :atar_percentage, nil
    end
  end
end

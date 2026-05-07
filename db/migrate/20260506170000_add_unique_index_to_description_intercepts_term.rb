Sequel.migration do
  up do
    duplicates = fetch(<<~SQL).map(:normalised_term)
      SELECT lower(trim(term)) AS normalised_term
      FROM description_intercepts
      GROUP BY lower(trim(term))
      HAVING count(*) > 1
    SQL

    if duplicates.any?
      raise Sequel::Error, "Cannot add unique description intercept term index while duplicates exist: #{duplicates.join(', ')}"
    end

    run 'UPDATE description_intercepts SET term = lower(trim(term))'
    run 'DROP INDEX IF EXISTS description_intercepts_term_index'

    alter_table :description_intercepts do
      add_unique_constraint :term, name: :description_intercepts_term_unique
    end
  end

  down do
    alter_table :description_intercepts do
      drop_constraint :description_intercepts_term_unique
      add_index :term
    end
  end
end

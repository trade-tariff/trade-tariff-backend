Sequel.migration do
  up do
    alter_table :description_intercepts do
      add_column :message_header, String, text: true
      add_constraint :description_intercepts_term_not_alias, Sequel.lit('NOT (term = ANY(COALESCE(aliases, ARRAY[]::text[])))')
    end
  end

  down do
    alter_table :description_intercepts do
      drop_constraint :description_intercepts_term_not_alias
      drop_column :message_header
    end
  end
end

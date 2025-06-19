# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table :live_issues do
      add_column :suggested_action, String, size: 256
    end
  end

  down do
    alter_table :live_issues do
      drop_column :suggested_action
    end
  end
end

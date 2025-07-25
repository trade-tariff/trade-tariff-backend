# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table(:public__live_issues) do
      set_column_type :description, :text
      set_column_type :suggested_action, :text
    end
  end

  down do
    alter_table(:public__live_issues) do
      set_column_type :description, String, size: 256
      set_column_type :suggested_action, String, size: 256
    end
  end
end

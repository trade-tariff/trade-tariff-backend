# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table(:public__live_issues) do
      set_column_allow_null :commodities
    end
  end

  down do
    alter_table(:public__live_issues) do
      set_column_not_null :commodities
    end
  end
end

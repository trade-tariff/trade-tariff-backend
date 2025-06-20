# frozen_string_literal: true

Sequel.migration do
  up do
    unless self[:public__live_issues].columns.include?(:suggested_action)
      alter_table(:public__live_issues) do
        add_column :suggested_action, String, size: 256
      end
    end
  end

  down do
    if self[:public__live_issues].columns.include?(:suggested_action)
      alter_table(:public__live_issues) do
        drop_column :suggested_action, String, size: 256
      end
    end
  end
end

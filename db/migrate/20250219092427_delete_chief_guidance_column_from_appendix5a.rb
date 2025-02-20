# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table(:appendix_5as) do
      drop_column :chief_guidance
    end
  end

  down do
    alter_table(:appendix_5as) do
      add_column :chief_guidance, String
    end
  end
end


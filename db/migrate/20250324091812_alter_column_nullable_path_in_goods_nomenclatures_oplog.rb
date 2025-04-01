# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table :goods_nomenclatures_oplog do
      set_column_allow_null :path
      set_column_default :path, []
    end
  end

  down do
    alter_table :goods_nomenclatures_oplog do
      set_column_not_null :path
      set_column_default :path, []
    end
  end
end

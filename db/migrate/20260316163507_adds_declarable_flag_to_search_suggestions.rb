# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table :search_suggestions do
      add_column :declarable, TrueClass, default: false
    end

    from(:search_suggestions)
      .where(goods_nomenclature_class: "Commodity")
      .update(declarable: true)

    declarable_heading_sids = Heading.declarable.map(:goods_nomenclatures__goods_nomenclature_sid)

    from(:search_suggestions)
      .where(goods_nomenclature_class: "Heading", goods_nomenclature_sid: declarable_heading_sids)
      .update(declarable: true)

    alter_table :search_suggestions do
      set_column_not_null :declarable
    end

    add_index :search_suggestions, :declarable
  end

  down do
    alter_table :search_suggestions do
      drop_column :declarable
    end
  end
end

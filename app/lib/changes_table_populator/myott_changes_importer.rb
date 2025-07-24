module ChangesTablePopulator
  class MyottChangesImporter < Importer
    IMPORT_FIELDS = %i[
      goods_nomenclature_item_id
      goods_nomenclature_sid
      productline_suffix
      end_line
      description
      change_type
      validity_start_date
      validity_end_date
      operation_date
      moved_to
    ].freeze

    def populate
      change_records = build_all_change_records(source_dataset)

      DB[:myott_changes]
        .insert_conflict(constraint: :myott_changes_upsert_unique)
        .import(IMPORT_FIELDS, change_records)
    end

    def source_dataset
      DB[source_table]
        .where(where_condition)
        .select(&select_condition)
    end

    protected

    def build_change_record(row:, is_end_line:, day: Time.zone.today)
      [
        row[:goods_nomenclature_item_id],
        row[:goods_nomenclature_sid],
        row[:producline_suffix] || row[:productline_suffix] || '80',
        is_end_line,
        description(row),
        change_type,
        row[:validity_start_date],
        row[:validity_end_date],
        day,
        has_moved?(row) ? moved_to(row, day) : nil,
      ]
    end

    def description(row)
      GoodsNomenclatureDescription
      .where(goods_nomenclature_item_id: row[:goods_nomenclature_item_id])
      .where(oid: GoodsNomenclatureDescription
      .where(goods_nomenclature_item_id: row[:goods_nomenclature_item_id])
      .select { max(:oid) })
      .get(:description)
    end

    def has_moved?(row)
      derived = GoodsNomenclatureOrigin.where(derived_goods_nomenclature_item_id: row[:goods_nomenclature_item_id], operation_date: day.beginning_of_day..day.end_of_day)
      derived.any?
    end

    def moved_to(row, day)
      derived = GoodsNomenclatureOrigin
                  .where(derived_goods_nomenclature_item_id: row[:goods_nomenclature_item_id], operation_date: day.beginning_of_day..day.end_of_day)
                  .select_map(:goods_nomenclature_item_id)

      derived.any? ? derived.join(', ') : nil
    end
  end
end

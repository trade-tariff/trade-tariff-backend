Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    attrs = {
      goods_nomenclature_indent_sid: 93_337,
      depth: 3,
      created_at: '2023-04-21 16:35:00',
    }

    if GoodsNomenclatures::TreeNodeOverride.where(attrs).count.zero?
      GoodsNomenclatures::TreeNodeOverride.create(attrs)
    end
  end

  down do
    attrs = {
      goods_nomenclature_indent_sid: 93_337,
      depth: 3,
      created_at: '2023-04-21 16:35:00',
    }

    GoodsNomenclatures::TreeNodeOverride.where(attrs).delete
  end
end

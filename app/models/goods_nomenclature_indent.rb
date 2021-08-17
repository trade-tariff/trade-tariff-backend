class GoodsNomenclatureIndent < Sequel::Model
  set_dataset order(Sequel.desc(:goods_nomenclature_indents__validity_end_date))

  plugin :oplog, primary_key: :goods_nomenclature_indent_sid
  plugin :time_machine, period_start_column: :goods_nomenclature_indents__validity_start_date,
                        period_end_column:   :goods_nomenclature_indents__validity_end_date

  set_primary_key [:goods_nomenclature_indent_sid]
end

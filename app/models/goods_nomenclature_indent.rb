class GoodsNomenclatureIndent < Sequel::Model
  NON_GROUPING_PRODUCTLINE_SUFFIX = '80'.freeze

  set_dataset order(Sequel.desc(:goods_nomenclature_indents__validity_end_date))

  plugin :oplog, primary_key: :goods_nomenclature_indent_sid
  plugin :time_machine

  set_primary_key [:goods_nomenclature_indent_sid]
end

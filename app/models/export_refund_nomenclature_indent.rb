class ExportRefundNomenclatureIndent < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: :export_refund_nomenclature_indents_sid

  set_primary_key [:export_refund_nomenclature_indents_sid]

  def number_indents
    number_export_refund_nomenclature_indents
  end
end

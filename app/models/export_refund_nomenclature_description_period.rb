class ExportRefundNomenclatureDescriptionPeriod < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: %i[export_refund_nomenclature_sid
                                 export_refund_nomenclature_description_period_sid]

  set_primary_key %i[export_refund_nomenclature_sid
                     export_refund_nomenclature_description_period_sid]
end

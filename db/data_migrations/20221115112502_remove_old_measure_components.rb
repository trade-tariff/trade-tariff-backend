Sequel.migration do
  # IMPORTANT! Data migrations should be Idempotent, they may get re-run as part
  # of data rollbacks

  up do
    if TradeTariffBackend.uk?
      Sequel::Model.db.transaction do
        table = Sequel::Model.db[:measure_components_oplog]

        table.where(measure_sid: 20_179_240, duty_expression_id: '04').delete
        table.where(measure_sid: 20_179_239, duty_expression_id: '04').delete
        table.where(measure_sid: 20_165_532, duty_expression_id: '17').delete
        table.where(measure_sid: 20_165_532, duty_expression_id: '19').delete
        table.where(measure_sid: 20_155_465, duty_expression_id: '04').delete
        table.where(measure_sid: 20_155_450, duty_expression_id: '04').delete
        table.where(measure_sid: 20_091_067, duty_expression_id: '19').delete
        table.where(measure_sid: 20_091_066, duty_expression_id: '19').delete
        table.where(measure_sid: 20_091_065, duty_expression_id: '19').delete
      end
    end
  end

  down do
    # Not implemented
  end
end

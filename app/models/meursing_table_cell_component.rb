class MeursingTableCellComponent < Sequel::Model
  plugin :oplog, primary_key: %i[meursing_table_plan_id
                                 heading_number
                                 row_column_code
                                 meursing_additional_code_sid]

  set_primary_key %i[meursing_table_plan_id heading_number
                     row_column_code meursing_additional_code_sid]
end

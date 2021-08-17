class MeursingSubheading < Sequel::Model
  plugin :oplog, primary_key: %i[meursing_table_plan_id
                                 meursing_heading_number
                                 row_column_code
                                 subheading_sequence_number]

  set_primary_key %i[meursing_table_plan_id meursing_heading_number row_column_code
                     subheading_sequence_number]
end

dataset = Sequel::Model.db[:chief_comm]
              .select(Sequel.as(:tbl91__tbl_code, :first_quantity_code))
              .select_more(Sequel.qualify(:chief_comm, :cmdty_code))
              .select_more(Sequel.qualify(:chief_comm, :fe_tsmp))
              .select_more(Sequel.qualify(:chief_comm, :audit_tsmp))
              .select_more(Sequel.qualify(:chief_comm, :le_tsmp))
              .select_more(Sequel.as(:tbl92__tbl_code, :second_quantity_code))
              .select_more(Sequel.as(:tbl93__tbl_code, :third_quantity_code))
              .select_more(Sequel.as(:tbl91__tbl_txt, :first_quantity_description))
              .select_more(Sequel.as(:tbl92__tbl_txt, :second_quantity_description))
              .select_more(Sequel.as(:tbl93__tbl_txt, :third_quantity_description))
              .join_table(:left, :chief_tbl9, { tbl91__tbl_code: :chief_comm__uoq_code_cdu1,
                                                tbl91__tbl_type: 'UNOQ' }, table_alias: :tbl91)
              .join_table(:left, :chief_tbl9, { tbl92__tbl_code: :chief_comm__uoq_code_cdu2,
                                                tbl92__tbl_type: 'UNOQ' }, table_alias: :tbl92)
              .join_table(:left, :chief_tbl9, { tbl93__tbl_code: :chief_comm__uoq_code_cdu3,
                                                tbl93__tbl_type: 'UNOQ' }, table_alias: :tbl93)
              .filter { Sequel.~(chief_comm__uoq_code_cdu1: nil) | Sequel.~(chief_comm__uoq_code_cdu2: nil) | Sequel.~(chief_comm__uoq_code_cdu3: nil) }
              .order(Sequel.asc(:audit_tsmp))
              .from_self(alias: :chief_comm)

class NationalMeasurementUnitSet < Sequel::Model(dataset)
  # set_primary_key [:tbl_code]
  set_primary_key %i[fe_tsmp cmdty_code audit_tsmp]
  plugin :time_machine

  def national_measurement_unit_set_units
    [NationalMeasurementUnit.new(measurement_unit_code: first_quantity_code,
                                 description: first_quantity_description,
                                 level: 1,
                                 parent_pk: pk),
     NationalMeasurementUnit.new(measurement_unit_code: second_quantity_code,
                                 description: second_quantity_description,
                                 level: 2,
                                 parent_pk: pk),
     NationalMeasurementUnit.new(measurement_unit_code: third_quantity_code,
                                 description: third_quantity_description,
                                 level: 3,
                                 parent_pk: pk)]
  end
end

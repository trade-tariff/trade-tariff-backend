class AdditionalCodeDescriptionPeriod < Sequel::Model
  plugin :oplog, primary_key: %i[additional_code_description_period_sid
                                 additional_code_sid
                                 additional_code_type_id], materialized: true
  plugin :time_machine

  set_primary_key %i[additional_code_description_period_sid
                     additional_code_sid
                     additional_code_type_id]

  one_to_one :additional_code_description, key: %i[additional_code_description_period_sid
                                                   additional_code_sid],
                                           primary_key: %i[additional_code_description_period_sid
                                                           additional_code_sid]
end

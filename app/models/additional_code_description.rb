class AdditionalCodeDescription < Sequel::Model
  include Formatter

  plugin :time_machine
  plugin :oplog, primary_key: %i[additional_code_description_period_sid additional_code_sid]

  set_primary_key %i[additional_code_description_period_sid additional_code_sid]

  format :formatted_description, with: DescriptionFormatter,
                                 using: :description

  # one_to_one :additional_code_description_period, key: [:additional_code_description_period_sid, :additional_code_sid, :additional_code_type_id]

  # many_to_one :language
  # many_to_one :additional_code_type, key: :additional_code_type_id
  # many_to_one :additional_code, key: :additional_code_sid
end

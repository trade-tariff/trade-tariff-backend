class AdditionalCode < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: :additional_code_sid
  plugin :conformance_validator

  set_primary_key [:additional_code_sid]

  many_to_many :additional_code_descriptions,
               join_table: :additional_code_description_periods,
               left_primary_key: :additional_code_sid,
               left_key: :additional_code_sid,
               right_key: %i[additional_code_description_period_sid
                             additional_code_sid],
               right_primary_key: %i[additional_code_description_period_sid
                                     additional_code_sid] do |ds|
    ds.with_actual(AdditionalCodeDescriptionPeriod)
      .order(Sequel.desc(:additional_code_description_periods__validity_start_date))
  end

  one_to_many :measures, key: :additional_code_sid,
                         primary_key: :additional_code_sid

  def additional_code_description
    additional_code_descriptions.first
  end

  one_to_one :meursing_additional_code, key: :additional_code,
                                        primary_key: :additional_code

  one_to_one :export_refund_nomenclature, key: :export_refund_code,
                                          primary_key: :additional_code

  delegate :description, :formatted_description, to: :additional_code_description

  def code
    "#{additional_code_type_id}#{additional_code}"
  end

  def id
    additional_code_sid
  end
end

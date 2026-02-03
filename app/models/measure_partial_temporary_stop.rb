class MeasurePartialTemporaryStop < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: %i[measure_sid
                                 partial_temporary_stop_regulation_id]

  set_primary_key %i[measure_sid partial_temporary_stop_regulation_id]

  alias_attribute :officialjournal_number, :partial_temporary_stop_regulation_officialjournal_number
  alias_attribute :officialjournal_page, :partial_temporary_stop_regulation_officialjournal_page

  def regulation_id
    partial_temporary_stop_regulation_id
  end

  def effective_end_date
    validity_end_date.presence&.to_date
  end

  def effective_start_date
    validity_start_date.to_date
  end

  def role
    nil
  end
end

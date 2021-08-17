class ModificationRegulation < Sequel::Model
  plugin :oplog, primary_key: %i[modification_regulation_id
                                 modification_regulation_role]
  plugin :time_machine, period_start_column: :modification_regulations__validity_start_date,
                        period_end_column: :effective_end_date

  set_primary_key %i[modification_regulation_id modification_regulation_role]

  one_to_one :base_regulation, key: %i[base_regulation_id base_regulation_role],
                               primary_key: %i[base_regulation_id base_regulation_role]

  def regulation_id
    modification_regulation_id
  end

  # TODO: confirm this assumption
  # 0 not replaced
  # 1 fully replaced
  # 2 partially replaced
  def fully_replaced?
    replacement_indicator == 1
  end
end

class BaseRegulation < Sequel::Model
  plugin :oplog, primary_key: %i[base_regulation_id base_regulation_role]
  plugin :time_machine, period_end_column: :effective_end_date

  set_primary_key %i[base_regulation_id base_regulation_role]

  one_to_one :complete_abrogation_regulation, key: %i[complete_abrogation_regulation_id
                                                      complete_abrogation_regulation_role]

  def regulation_id
    base_regulation_id
  end

  def not_completely_abrogated?
    complete_abrogation_regulation.blank?
  end

  def role
    base_regulation_role
  end
end

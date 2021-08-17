class MonetaryUnit < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: :monetary_unit_code

  set_primary_key [:monetary_unit_code]

  one_to_one :monetary_unit_description, key: :monetary_unit_code,
                                         primary_key: :monetary_unit_code

  delegate :description, :abbreviation, to: :monetary_unit_description

  def to_s
    monetary_unit_code
  end
end

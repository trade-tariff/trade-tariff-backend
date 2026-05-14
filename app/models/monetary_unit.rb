class MonetaryUnit < Sequel::Model
  set_primary_key [:monetary_unit_code]

  plugin :time_machine
  plugin :oplog, primary_key: :monetary_unit_code
  plugin :static_cache, frozen: false unless Rails.env.test?

  one_to_one :monetary_unit_description, key: :monetary_unit_code,
                                         primary_key: :monetary_unit_code

  delegate :description, :abbreviation, to: :monetary_unit_description

  def to_s
    monetary_unit_code
  end
end

class Measurement < Sequel::Model
  plugin :oplog, primary_key: %i[measurement_unit_code
                                 measurement_unit_qualifier_code]

  set_primary_key %i[measurement_unit_code measurement_unit_qualifier_code]
end

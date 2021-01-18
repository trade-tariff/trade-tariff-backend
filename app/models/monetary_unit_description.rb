class MonetaryUnitDescription < Sequel::Model
  plugin :oplog, primary_key: :monetary_unit_code
  plugin :conformance_validator

  set_primary_key [:monetary_unit_code]

  def abbreviation
    {
      'EUC' => 'EUR (EUC)',
    }[monetary_unit_code]
  end
end

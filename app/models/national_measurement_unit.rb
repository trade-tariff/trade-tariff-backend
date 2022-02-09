class NationalMeasurementUnit
  # parent_pk - NationalMeasurementUnitSer.primary_key
  # level - values 1,2 or 3
  attr_reader :measurement_unit_code, :level, :parent_pk

  def initialize(attributes = {})
    @measurement_unit_code = attributes.fetch(:measurement_unit_code, nil)
    @description = attributes.fetch(:description, nil)
    @level = attributes.fetch(:level)
    @parent_pk = attributes.fetch(:parent_pk, [])
  end

  def description
    self.class.description_map.fetch(measurement_unit_code, nil)
  end

  def original_description
    @description
  end

  delegate :present?, to: :description

  def to_s
    description
  end

  def pk
    [level] + parent_pk
  end

  def self.description_map
    {
      '048' => 'Hectokilogram Net Dry Matter (100kg/net mas)',
      '070' => 'Standard Litre of Hydrocarbon Oil',
      '100' => '% Lactic Matter / 100 Kg Product',
      '101' => '% Lactic Dry Matter / 100 Kg Product',
      '102' => '% Sucrose Content / 100 Kg Net',
      '104' => '% Added Sugar / 100 Kg',
      '106' => '% Actual Alcoholic Strength / Hectolitre',
    }
  end
end

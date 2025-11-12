class MeasurementUnit < Sequel::Model
  STANDARD_MEASUREMENT_UNIT_CODE_LENGTH = 3
  MEASUREMENT_UNIT_OVERLAY_FILE = 'db/measurement_units.json'.freeze

  plugin :oplog, primary_key: :measurement_unit_code
  plugin :time_machine

  set_primary_key [:measurement_unit_code]

  one_to_one :measurement_unit_description, primary_key: :measurement_unit_code,
                                            key: :measurement_unit_code

  one_to_many :measurement_unit_abbreviations, primary_key: :measurement_unit_code,
                                               key: :measurement_unit_code

  alias_method :id, :measurement_unit_code

  delegate :description, to: :measurement_unit_description

  class << self
    def units(unit_code, unit_key)
      unit = measurement_units[unit_key] || build_missing_measurement_unit(unit_code, unit_key)

      if unit['compound_units'].present?
        compound_units_for(unit)
      else
        [unit]
      end
    end

    def type_for(unit_code)
      measurement_units.dig(unit_code, 'measurement_unit_type')
    end

    def coerced_unit_for(unit_code)
      coerced_units.fetch(unit_code, unit_code)
    end

    def coerced_units
      @coerced_units ||= measurement_units.each_with_object({}) do |(k, v), acc|
        acc[k] = v['coerced_measurement_unit_code'] if v['coerced_measurement_unit_code'].present?
      end
    end

    def weight_units
      @weight_units ||= begin
        units = measurement_units.select { |_k, v| v['measurement_unit_type'] == 'weight' }.keys

        Set.new(units)
      end
    end

    def volume_units
      @volume_units ||= begin
        units = measurement_units.select { |_k, v| v['measurement_unit_type'] == 'volume' }.keys

        Set.new(units)
      end
    end

    def percentage_abv_units
      @percentage_abv_units ||= begin
        units = measurement_units.select { |_k, v| v['measurement_unit_type'] == 'percentage_abv' }.keys

        Set.new(units)
      end
    end

    def measurement_units
      @measurement_units ||= JSON.parse(File.read(Rails.root.join(MEASUREMENT_UNIT_OVERLAY_FILE)))
    end

    private

    def compound_units_for(unit)
      unit['compound_units'].flat_map do |unit_key|
        units(unit['measurement_unit_code'], unit_key)
      end
    end

    def build_missing_measurement_unit(unit_code, unit_key)
      unit = find(measurement_unit_code: unit_code)

      qualifier_code = if unit_key.length > STANDARD_MEASUREMENT_UNIT_CODE_LENGTH
                         unit_key[STANDARD_MEASUREMENT_UNIT_CODE_LENGTH..]
                       else
                         ''
                       end

      {
        'measurement_unit_code' => unit&.measurement_unit_code || unit_code,
        'measurement_unit_qualifier_code' => qualifier_code,
        'abbreviation' => unit&.abbreviation,
        'unit_question' => "Please enter unit: #{unit&.description || unit_code}",
        'unit_hint' => "Please correctly enter unit: #{unit&.description || unit_code}",
        'unit' => nil,
      }
    end
  end

  def to_s
    description
  end

  def abbreviation(options = {})
    measurement_unit_abbreviation(options)&.abbreviation || description
  end

  def expansion(options = {})
    code = measurement_unit_code
    code = measurement_unit_code + options[:measurement_unit_qualifier].measurement_unit_qualifier_code if options[:measurement_unit_qualifier]
    measurement_unit = MeasurementUnit.measurement_units[code]
    measurement_unit['expansion'] if measurement_unit
  end

  def measurement_unit_abbreviation(options = {})
    measurement_unit_qualifier = options[:measurement_unit_qualifier]
    measurement_unit_abbreviations.find do |abbreviation|
      abbreviation.measurement_unit_qualifier == measurement_unit_qualifier.try(:measurement_unit_qualifier_code)
    end
  end
end

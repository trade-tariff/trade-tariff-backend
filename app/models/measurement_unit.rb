class MeasurementUnit < Sequel::Model
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

    private

    def compound_units_for(unit)
      unit['compound_units'].flat_map do |unit_key|
        units(unit['measurement_unit_code'], unit_key)
      end
    end

    def measurement_units
      @measurement_units ||=
        begin
          file = File.join(::Rails.root, 'db', 'measurement_units.json').freeze
          JSON.parse(File.read(file))
        end
    end

    def build_missing_measurement_unit(unit_code, unit_key)
      unit = find(measurement_unit_code: unit_code)

      qualifier_code = unit_key.length == 4 ? unit_key[3..] : ''

      if unit.present?
        Sentry.capture_message("Missing measurement unit in database for measurement unit key: #{unit_key}")
      else
        Sentry.capture_message("Missing measurement unit in measurement_units.yml: #{unit_key}")
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

  def measurement_unit_abbreviation(options = {})
    measurement_unit_qualifier = options[:measurement_unit_qualifier]
    measurement_unit_abbreviations.find do |abbreviation|
      abbreviation.measurement_unit_qualifier == measurement_unit_qualifier.try(:measurement_unit_qualifier_code)
    end
  end
end

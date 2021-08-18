class MeasurementUnit < Sequel::Model
  class InvalidMeasurementUnit < RuntimeError
    def initialize(unit_key)
      super "Requested invalid measurement unit: #{unit_key}"
    end
  end

  plugin :oplog, primary_key: :measurement_unit_code
  plugin :time_machine

  set_primary_key [:measurement_unit_code]

  one_to_one :measurement_unit_description, primary_key: :measurement_unit_code,
                                            key: :measurement_unit_code

  one_to_many :measurement_unit_abbreviations, primary_key: :measurement_unit_code,
                                               key: :measurement_unit_code

  delegate :description, to: :measurement_unit_description

  class << self
    def measurement_unit(unit_key)
      measurement_units[unit_key] ||= build_missing_measurement_unit(unit_key)
    end

    private

    def measurement_units
      @measurement_units ||=
        begin
          file = File.join(::Rails.root, 'db', 'measurement_units.json').freeze
          JSON.parse(File.read(file))
        end
    end

    def build_missing_measurement_unit(unit_key)
      raise InvalidMeasurementUnit, unit_key unless unit = self[unit_key]

      Raven.capture_message("Missing measurement unit in measurement_units.yml: #{unit_key}")

      {
        'measurement_unit_code' => unit.measurement_unit_code,
        'measurement_unit_qualifier_code' => '',
        'abbreviation' => '',
        'unit_question' => "Please enter unit: #{unit.description}",
        'unit_hint' => nil,
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

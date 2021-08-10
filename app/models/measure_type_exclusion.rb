require 'csv'

class MeasureTypeExclusion
  DEFAULT_SOURCE = Rails.root.join(
    "db/#{TradeTariffBackend.service}_measure_type_exclusions.csv",
  ).freeze

  class_attribute :exclusions
  self.exclusions = nil

  class << self
    def load_from_string(data)
      CSV.parse(data, headers: true, &method(:load_row))

      self
    end

    def load_from_file(file = DEFAULT_SOURCE)
      CSV.foreach(file, headers: true, &method(:load_row))

      self
    end

    def reset_data
      self.exclusions = nil

      self
    end

    def find(measure_type_id, geographical_area_id)
      load_from_file if exclusions.nil?

      exclusions[[measure_type_id.to_s, geographical_area_id.to_s]] || []
    end

    def find_geographical_areas(measure_type_id, geographical_area_id)
      country_codes = find(measure_type_id, geographical_area_id)
      return [] if country_codes.empty?

      GeographicalArea.where(geographical_area_id: country_codes).all
    end

  private

    def load_row(row)
      row_key = row.values_at('measure_type_id', 'geographical_area_id')

      self.exclusions ||= {}
      self.exclusions[row_key] ||= []
      self.exclusions[row_key] << row['excluded_country']
    end
  end
end

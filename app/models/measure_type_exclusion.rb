require 'csv'

class MeasureTypeExclusion
  class_attribute :exclusions_by_service
  self.exclusions_by_service = {}

  class << self
    def source_for(service)
      Rails.root.join("db/#{service}_measure_type_exclusions.csv")
    end

    def exclusions
      exclusions_by_service[TradeTariffBackend.service]
    end

    def load_from_file(file = source_for(TradeTariffBackend.service))
      service = TradeTariffBackend.service
      exclusions_by_service[service] = {}

      CSV.foreach(file, headers: true) do |row|
        load_row(row, service)
      end

      self
    end

    def reset_data
      self.exclusions_by_service = {}

      self
    end

    def find(measure_type_id, geographical_area_id)
      service = TradeTariffBackend.service
      load_from_file unless exclusions_by_service.key?(service)

      exclusions_by_service[service][[measure_type_id.to_s, geographical_area_id.to_s]] || []
    end

    def find_geographical_areas(measure_type_id, geographical_area_id)
      country_codes = find(measure_type_id, geographical_area_id)
      return [] if country_codes.empty?

      GeographicalArea.where(geographical_area_id: country_codes).order(:geographical_area_id).all
    end

  private

    def load_row(row, service)
      row_key = row.values_at('measure_type_id', 'geographical_area_id')

      exclusions_by_service[service][row_key] ||= []
      exclusions_by_service[service][row_key] << row['excluded_country']
    end
  end
end

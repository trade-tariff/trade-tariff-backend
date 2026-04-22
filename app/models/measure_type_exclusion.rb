require 'csv'

class MeasureTypeExclusion
  SOURCES = {
    'uk' => Rails.root.join('db/uk_measure_type_exclusions.csv').freeze,
    'xi' => Rails.root.join('db/xi_measure_type_exclusions.csv').freeze,
  }.freeze

  class << self
    def load_from_file(file = SOURCES.fetch(TradeTariffBackend.service))
      exclusions_by_service[TradeTariffBackend.service] = parse_file(file)
      self
    end

    def reset_data
      @exclusions_by_service = nil
      self
    end

    def find(measure_type_id, geographical_area_id)
      exclusions[[measure_type_id.to_s, geographical_area_id.to_s]] || []
    end

    def find_geographical_areas(measure_type_id, geographical_area_id)
      country_codes = find(measure_type_id, geographical_area_id)
      return [] if country_codes.empty?

      GeographicalArea.where(geographical_area_id: country_codes).order(:geographical_area_id).all
    end

    # Returns the exclusion hash for the current service, loading from disk on
    # first access. Keyed by [measure_type_id, geographical_area_id] pairs.
    def exclusions
      service = TradeTariffBackend.service
      exclusions_by_service[service] ||= parse_file(SOURCES.fetch(service))
    end

    private

    def parse_file(file)
      data = {}
      CSV.foreach(file, headers: true) do |row|
        row_key = row.values_at('measure_type_id', 'geographical_area_id')
        data[row_key] ||= []
        data[row_key] << row['excluded_country']
      end
      data
    end

    def exclusions_by_service
      @exclusions_by_service ||= {}
    end
  end
end

require 'csv'

class MeasureTypeExclusion
  SOURCES = {
    'uk' => Rails.root.join('db/uk_measure_type_exclusions.csv').freeze,
    'xi' => Rails.root.join('db/xi_measure_type_exclusions.csv').freeze,
  }.freeze

  class << self
    def load_from_file(file = SOURCES.fetch(TradeTariffBackend.service))
      service = TradeTariffBackend.service
      exclusions_by_service[service] = parse_file(file)
      # Clear the geo area cache so it is rebuilt lazily on the next
      # find_geographical_areas call. We cannot preload here because
      # load_from_file may run before DB records exist (e.g. in tests).
      geographical_areas_by_service.delete(service)
      self
    end

    def reset_data
      @exclusions_by_service = nil
      @geographical_areas_by_service = nil
      self
    end

    def find(measure_type_id, geographical_area_id)
      exclusions[[measure_type_id.to_s, geographical_area_id.to_s]] || []
    end

    # Replaces the previous per-call GeographicalArea.where query.
    #
    # On first call after load (or reset), preloads ALL country codes referenced
    # in the exclusions CSV into a hash keyed by geographical_area_id. Subsequent
    # calls look up in that hash — no DB query.
    def find_geographical_areas(measure_type_id, geographical_area_id)
      country_codes = find(measure_type_id, geographical_area_id)
      return [] if country_codes.empty?

      country_codes.filter_map { |code| geographical_areas[code] }
                   .sort_by(&:geographical_area_id)
    end

    # Returns the exclusion hash for the current service, loading from disk on
    # first access. Keyed by [measure_type_id, geographical_area_id] pairs.
    def exclusions
      service = TradeTariffBackend.service
      exclusions_by_service[service] ||= parse_file(SOURCES.fetch(service))
    end

    private

    # Returns a hash of geographical_area_id => GeographicalArea for every
    # country code that appears in the CSV, loaded in a single DB query.
    def geographical_areas
      service = TradeTariffBackend.service
      geographical_areas_by_service[service] ||= preload_geographical_areas(exclusions)
    end

    def preload_geographical_areas(exclusions_data)
      all_codes = exclusions_data.values.flatten.uniq
      return {} if all_codes.empty?

      GeographicalArea
        .where(geographical_area_id: all_codes)
        .all
        .index_by(&:geographical_area_id)
    end

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

    def geographical_areas_by_service
      @geographical_areas_by_service ||= {}
    end
  end
end

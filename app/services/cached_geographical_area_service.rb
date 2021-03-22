class CachedGeographicalAreaService
  DEFAULT_INCLUDES = [:contained_geographical_areas].freeze
  GEOGRAPHICAL_AREAS_EAGER_GRAPH = :geographical_area_descriptions
  TTL = 24.hours

  def initialize(actual_date, countries = false)
    @countries = countries
    @actual_date = actual_date
  end

  def call
    Rails.cache.fetch(cache_key, expires_in: TTL) do
      Api::V2::GeographicalAreaTreeSerializer.new(
        sorted_areas.all,
        include: DEFAULT_INCLUDES,
      ).serializable_hash
    end
  end

  private

  attr_reader :countries, :actual_date

  def sorted_areas
    areas.exclude(
      geographical_area_id: excluded_geographical_area_ids,
    ).order(
      Sequel.asc(:geographical_area_id),
    )
  end

  def areas
    return country_geographical_areas if countries

    geographical_areas
  end

  def cache_key
    return "_geographical-areas-countries-#{actual_date}" if countries

    "_geographical-areas-index-#{actual_date}"
  end

  def country_geographical_areas
    GeographicalArea.eager(GEOGRAPHICAL_AREAS_EAGER_GRAPH).actual.countries
  end

  def geographical_areas
    GeographicalArea.eager(GEOGRAPHICAL_AREAS_EAGER_GRAPH).actual.areas
  end

  def excluded_geographical_area_ids
    return %w[XU] if TradeTariffBackend.xi?

    %w[GB XU XI]
  end
end

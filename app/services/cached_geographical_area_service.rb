class CachedGeographicalAreaService
  GLOBALLY_EXCLUDED_GEOGRAPHICAL_AREA_IDS = %w[
    EU
    GG
    JE
    QP
    QQ
    QR
    QS
    QU
    QV
    QW
    QX
    QY
    QZ
  ].freeze

  DEFAULT_INCLUDES = [:contained_geographical_areas].freeze
  GEOGRAPHICAL_AREAS_EAGER_GRAPH = %i[
    geographical_area_descriptions
    contained_geographical_areas
  ].freeze
  TTL = 24.hours

  def initialize(actual_date, exclude_none: false, countries: false)
    @countries = countries
    @exclude_none = exclude_none
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

  attr_reader :actual_date, :countries, :exclude_none

  def sorted_areas
    excluded_areas.order(Sequel.asc(:geographical_area_id))
  end

  def excluded_areas
    if exclude_none
      areas
    else
      areas.exclude(
        geographical_area_id: excluded_geographical_area_ids + GLOBALLY_EXCLUDED_GEOGRAPHICAL_AREA_IDS,
      )
    end
  end

  def areas
    return country_geographical_areas if countries

    geographical_areas
  end

  def cache_key
    "_geographical-areas-#{actual_date}-#{countries}-#{exclude_none}"
  end

  def country_geographical_areas
    GeographicalArea.eager(GEOGRAPHICAL_AREAS_EAGER_GRAPH).actual.countries
  end

  def geographical_areas
    GeographicalArea.eager(GEOGRAPHICAL_AREAS_EAGER_GRAPH).actual.areas
  end

  def excluded_geographical_area_ids
    TradeTariffBackend.xi? ? %w[XU XI] : %w[GB XU XI]
  end
end

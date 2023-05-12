class CachedSubheadingService
  TTL = 23.hours # Expire just before the ETL job runs and prewarms expensive subheadings
  CACHE_VERSION = 1

  DEFAULT_INCLUDES = [
    :section,
    :heading,
    :chapter,
    'chapter.guides',
    :footnotes,
    :commodities,
    'commodities.overview_measures',
    'commodities.overview_measures.duty_expression',
    'commodities.overview_measures.measure_type',
    'commodities.overview_measures.additional_code',
  ].freeze

  def initialize(subheading, actual_date, eager_reload: true)
    @subheading = subheading
    @actual_date = actual_date.to_date.to_formatted_s(:db)
    @eager_reload = eager_reload
  end

  def call
    Rails.cache.fetch(cache_key, expires_in: TTL) do
      Api::V2::Subheadings::SubheadingSerializer
        .new(presented_subheading, options)
        .serializable_hash
    end
  end

  def cache_key
    "_subheading-#{@subheading.goods_nomenclature_sid}-#{@actual_date}-v#{CACHE_VERSION}"
  end

  private

  def presented_subheading
    Api::V2::Subheadings::SubheadingPresenter.new(ns_eager_loaded_subheading)
  end

  def options
    opts = {}
    opts[:is_collection] = false
    opts[:include] = DEFAULT_INCLUDES
    opts
  end

  def ns_eager_loaded_subheading
    return @subheading unless eager_reload?

    @ns_eager_loaded_subheading ||=
      Subheading
        .actual
        .non_hidden
        .where(goods_nomenclature_sid: @subheading.goods_nomenclature_sid)
        .eager(*HeadingService::Serialization::NsNondeclarableService::HEADING_EAGER_LOAD)
        .take
  end

  def eager_reload?
    @eager_reload
  end
end

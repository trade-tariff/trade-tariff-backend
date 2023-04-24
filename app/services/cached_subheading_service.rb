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
    @use_nested_set = true
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
    "_subheading-#{@subheading.goods_nomenclature_sid}-#{@actual_date}#{cache_version}"
  end

  private

  def presented_subheading
    if use_nested_set?
      return Api::V2::Subheadings::SubheadingPresenter.new(ns_eager_loaded_subheading)
    end

    @presented_subheading ||= begin
      presenter_serialized = Cache::HeadingSerializer.new(@subheading).as_json

      # We use Hashie::TariffMash as a proxy for mutating state on something that acts like a Heading and replaces the presenter pattern we use elsewhere
      presented = Hashie::TariffMash.new(presenter_serialized)
      presented.section_id = presented.section.id
      presented.chapter_id = presented.chapter.id
      presented.heading_id = presented.heading.id
      presented.commodity_ids = presented.commodities.map(&:id)
      presented.footnote_ids = presented.footnotes.map(&:id)
      presented.ancestors = @subheading.ancestors
      presented.ancestor_ids = presented.ancestors.map(&:id)

      presented.chapter.guide_ids = presented.chapter.guides.map(&:id)
      presented.commodities.each do |commodity|
        current_indents = commodity.goods_nomenclature_indents.max_by(&:validity_start_date)
        commodity.number_indents = current_indents.number_indents
        commodity.producline_suffix = current_indents.productline_suffix

        current_description = commodity.goods_nomenclature_descriptions.max_by(&:validity_start_date)
        commodity.description = current_description.description
        commodity.formatted_description = current_description.formatted_description
        commodity.description_plain = current_description.description_plain
        commodity.overview_measure_ids = commodity.overview_measures.map(&:measure_sid)
        commodity.overview_measures.each do |measure|
          measure.duty_expression_id = measure.duty_expression.id
          measure.measure_type_id = measure.measure_type_id
        end
      end

      AnnotatedCommodityService.new(presented).call

      presented
    end
  end

  def cache_version
    "-v#{CACHE_VERSION}" if use_nested_set?
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

  def use_nested_set?
    @use_nested_set
  end

  def eager_reload?
    @eager_reload
  end
end

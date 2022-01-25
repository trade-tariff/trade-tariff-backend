class CachedSubheadingService
  TTL = 24.hours

  DEFAULT_INCLUDES = [
    :section,
    :chapter,
    'chapter.guides',
    :footnotes,
    :commodities,
    'commodities.overview_measures',
    'commodities.overview_measures.duty_expression',
    'commodities.overview_measures.measure_type',
  ].freeze

  def initialize(subheading, actual_date)
    @subheading = subheading
    @actual_date = actual_date
  end

  def call
    Rails.cache.fetch(cache_key, expires_in: TTL) do
      Api::V2::Subheadings::SubheadingSerializer.new(presented_subheading, options).serializable_hash
    end
  end

  private

  def presented_subheading
    @presented_subheading ||= begin
      presenter_serialized = Cache::HeadingSerializer.new(@subheading).as_json

      # We use Hashie::TariffMash as a proxy for mutating state on something that acts like a Heading and replaces the presenter pattern we use elsewhere
      presented = Hashie::TariffMash.new(presenter_serialized)
      presented.section_id = presented.section.id
      presented.chapter_id = presented.chapter.id
      presented.heading_id = presented.heading.id
      presented.commodity_ids = presented.commodities.map(&:id)
      presented.footnote_ids = presented.footnotes.map(&:id)

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
          measure.measure_type_id = measure.measure_type.id
        end
      end

      AnnotatedCommodityService.new(presented).call

      presented
    end
  end

  def cache_key
    "_subheading-#{@subheading.goods_nomenclature_sid}-#{@actual_date}"
  end

  def options
    opts = {}
    opts[:is_collection] = false
    opts[:include] = DEFAULT_INCLUDES
    opts
  end
end

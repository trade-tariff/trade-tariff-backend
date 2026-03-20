class CachedCommodityDescriptionService
  CACHE_VERSION = '1'.freeze
  CACHE_PREFIX = "_commodity-description-v#{CACHE_VERSION}".freeze
  CACHE_EXPIRY = 30.days.freeze
  HIERARCHY_CACHE_SUFFIX = 'hierarchy'.freeze

  def self.cache_for_codes(codes, include_hierarchy: false)
    return {} if codes.empty?

    normalized_codes = codes.uniq.map(&:to_s)
    resolver = new(cache: false)
    resolved_descriptions = resolver.send(:resolve_descriptions_for_codes, normalized_codes, include_hierarchy: include_hierarchy)

    Rails.cache.write_multi(
      resolved_descriptions.transform_keys { |code| cache_key(code, include_hierarchy: include_hierarchy) },
      expires_in: CACHE_EXPIRY,
    )

    resolved_descriptions
  end

  def self.fetch_for_codes(codes, include_hierarchy: false)
    return {} if codes.empty?

    normalized_codes = codes.uniq.map(&:to_s)
    Rails.logger.info "Fetching descriptions for #{normalized_codes.size} codes from cache"
    cache_keys_by_code = normalized_codes.index_with { |code| cache_key(code, include_hierarchy: include_hierarchy) }
    cached_descriptions_by_key = Rails.cache.read_multi(*cache_keys_by_code.values)

    descriptions = {}
    missing_codes = []

    cache_keys_by_code.each do |code, cache_key|
      if cached_descriptions_by_key.key?(cache_key)
        descriptions[code] = cached_descriptions_by_key[cache_key]
      else
        missing_codes << code
      end
    end

    return descriptions if missing_codes.empty?

    Rails.logger.info "Fetching descriptions for #{missing_codes.size} codes not in cache"
    fetched_descriptions = cache_for_codes(missing_codes, include_hierarchy: include_hierarchy)

    descriptions.merge(fetched_descriptions)
  end

  def initialize(code = nil, cache: false)
    @code = code.to_s
    @cache = cache
  end

  def call
    return '' if code.empty?

    return resolve_description unless cache?

    Rails.cache.fetch(self.class.send(:cache_key, code, include_hierarchy: false)) do
      resolve_description
    end
  end

  def self.cache_key(code, include_hierarchy: false)
    suffix = include_hierarchy ? "-#{HIERARCHY_CACHE_SUFFIX}" : ''
    "#{CACHE_PREFIX}-#{code}#{suffix}"
  end
  private_class_method :cache_key

  private

  attr_reader :code

  def cache?
    @cache
  end

  def resolve_description
    resolve_descriptions_for_codes([code])[code].to_s
  end

  def resolve_descriptions_for_codes(codes, include_hierarchy: false)
    return {} if codes.empty?
    return resolve_hierarchy_for_codes(codes) if include_hierarchy

    descriptions = load_latest_formatted_descriptions(codes)
    other_codes = descriptions.select { |_code, description| other_description?(description) }.keys

    return descriptions if other_codes.empty?

    descriptions.merge(load_other_classification_descriptions(other_codes))
  end

  def resolve_hierarchy_for_codes(codes)
    latest_commodities = load_latest_commodities(codes)
    latest_formatted_descriptions = load_latest_formatted_descriptions(codes)

    latest_commodities.each_with_object({}) do |commodity, descriptions|
      fallback_description = latest_formatted_descriptions[commodity.goods_nomenclature_item_id].to_s
      levels = hierarchy_levels_for(commodity, fallback_description: fallback_description)
      descriptions[commodity.goods_nomenclature_item_id] = {
        plain_description: levels.last.to_s,
        hierarchy_levels: levels,
        has_heading: commodity.heading.present?,
      }
    end
  end

  def hierarchy_levels_for(commodity, fallback_description:)
    levels = commodity.classifiable_goods_nomenclatures
      .reject(&:chapter?)
      .map { |node| html_to_plain_text(node.formatted_description.to_s) }
      .reverse
      .reject(&:blank?)

    return levels if levels.present?

    fallback_description.present? ? [fallback_description] : []
  end

  def load_latest_commodities(codes)
    GoodsNomenclature
      .where(goods_nomenclatures__goods_nomenclature_item_id: codes)
      .distinct(:goods_nomenclatures__goods_nomenclature_item_id)
      .order(
        :goods_nomenclatures__goods_nomenclature_item_id,
        Sequel.desc(:goods_nomenclatures__validity_start_date, nulls: :last),
        Sequel.desc(:goods_nomenclatures__goods_nomenclature_sid),
      )
      .eager(
        :goods_nomenclature_descriptions,
        { ancestors: :goods_nomenclature_descriptions },
        { heading: :goods_nomenclature_descriptions },
      )
      .all
  end

  def load_other_classification_descriptions(codes)
    latest_commodities = load_latest_commodities(codes)

    latest_commodities.each_with_object({}) do |commodity, descriptions|
      desc = commodity.classification_description.to_s
      descriptions[commodity.goods_nomenclature_item_id] = html_to_plain_text(desc)
    end
  end

  def load_latest_formatted_descriptions(codes)
    return {} if codes.empty?

    GoodsNomenclatureDescription
      .where(goods_nomenclature_item_id: codes)
      .distinct(:goods_nomenclature_item_id)
      .order(:goods_nomenclature_item_id, Sequel.desc(:goods_nomenclature_description_period_sid))
      .each_with_object({}) do |record, descriptions|
        descriptions[record.goods_nomenclature_item_id] = html_to_plain_text(record.formatted_description.to_s)
      end
  end

  def html_to_plain_text(text)
    with_line_breaks = text.to_s.gsub(%r{<br\s*/?>}i, "\n")
    sanitized_text = html_sanitizer.sanitize(with_line_breaks)
    CGI.unescapeHTML(sanitized_text)
  end

  def html_sanitizer
    @html_sanitizer ||= Rails::HTML5::FullSanitizer.new
  end

  def other_description?(description)
    description.to_s.match?(/^other$/i)
  end
end

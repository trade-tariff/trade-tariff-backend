class CachedCommodityDescriptionService
  CACHE_VERSION = '1'.freeze

  def self.fetch_for_codes(codes)
    return {} if codes.empty?

    normalized_codes = codes.uniq
    cache_keys_by_code = normalized_codes.index_with { |code| cache_key(code) }
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

    resolver = new(cache: false)
    resolved_descriptions = TimeMachine.now do
      resolver.send(:resolve_descriptions_for_codes, missing_codes)
    end
    fetched_descriptions = missing_codes.index_with { |code| resolved_descriptions[code].to_s }

    Rails.cache.write_multi(
      fetched_descriptions.transform_keys { |code| cache_keys_by_code.fetch(code) },
    )

    descriptions.merge(fetched_descriptions)
  end

  def initialize(code = nil, cache: false)
    @code = code.to_s
    @cache = cache
  end

  def call
    return '' if code.empty?

    return resolve_description unless cache?

    Rails.cache.fetch(self.class.send(:cache_key, code)) do
      resolve_description
    end
  end

  def self.cache_key(code)
    "_commodity-description-v#{CACHE_VERSION}-#{code}"
  end
  private_class_method :cache_key

  private

  attr_reader :code

  def cache?
    @cache
  end

  def resolve_description
    TimeMachine.now do
      resolve_descriptions_for_codes([code])[code].to_s
    end
  end

  def resolve_descriptions_for_codes(codes)
    return {} if codes.empty?

    descriptions = load_latest_formatted_descriptions(codes)
    other_codes = descriptions.select { |_code, description| other_description?(description) }.keys

    return descriptions if other_codes.empty?

    descriptions.merge(load_other_classification_descriptions(other_codes))
  end

  def load_other_classification_descriptions(codes)
    latest_commodities = GoodsNomenclature
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

    latest_commodities.each_with_object({}) do |commodity, descriptions|
      descriptions[commodity.goods_nomenclature_item_id] = html_to_plain_text(commodity.classification_description.to_s)
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

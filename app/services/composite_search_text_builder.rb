class CompositeSearchTextBuilder
  def initialize(self_text_record, labels: nil, search_references: nil)
    @self_text_record = self_text_record
    @labels = labels
    @search_references = search_references
  end

  def call
    sections = [description_section]
    sections << also_known_as_section if also_known_as.any?
    sections << brands_section if brands.any?
    sections << references_section if reference_titles.any?
    sections.join("\n")
  end

  # Batch mode: preloads labels and search_references for a set of SIDs
  # to avoid N+1 queries.
  #
  # Returns a hash of { sid => composite_text }
  def self.batch(self_text_records)
    return {} if self_text_records.empty?

    sids = self_text_records.map(&:goods_nomenclature_sid)

    labels_by_sid = GoodsNomenclatureLabel
      .where(goods_nomenclature_sid: sids)
      .as_hash(:goods_nomenclature_sid)

    refs_by_sid = SearchReference
      .where(goods_nomenclature_sid: sids)
      .all
      .group_by(&:goods_nomenclature_sid)

    self_text_records.each_with_object({}) do |record, hash|
      sid = record.goods_nomenclature_sid
      builder = new(
        record,
        labels: labels_by_sid[sid],
        search_references: refs_by_sid[sid],
      )
      hash[sid] = builder.call
    end
  end

  private

  attr_reader :self_text_record, :labels, :search_references

  def description_section
    self_text_record.self_text
  end

  def also_known_as_section
    "Also known as: #{also_known_as.join(', ')}"
  end

  def brands_section
    "Brands: #{brands.join(', ')}"
  end

  def references_section
    "References: #{reference_titles.join(', ')}"
  end

  def also_known_as
    @also_known_as ||= [
      *label_field('colloquial_terms'),
      *label_field('synonyms'),
    ]
  end

  def brands
    @brands ||= label_field('known_brands')
  end

  def label_field(field)
    return [] unless labels

    values = labels.labels&.dig(field)
    return [] unless values.is_a?(Array)

    values.reject(&:blank?)
  end

  def reference_titles
    @reference_titles ||= (search_references || []).filter_map { |r| r.title.presence }
  end
end

class CompositeSearchTextBuilder
  def initialize(self_text_record, labels: nil, search_references: nil, atar_keywords: nil)
    @self_text_record = self_text_record
    @labels = labels
    @search_references = search_references
    @atar_keywords = atar_keywords
  end

  def call
    sections = [description_section]
    sections << also_known_as_section if also_known_as.any?
    sections << brands_section if brands.any?
    sections << references_section if reference_titles.any?
    sections << atar_keywords_section if normalized_atar_keywords.any?
    sections.join("\n")
  end

  # Batch mode: preloads labels and search_references for a set of SIDs
  # to avoid N+1 queries. Caller must ensure TimeMachine is set.
  #
  # Returns a hash of { sid => composite_text }
  def self.batch(self_text_records)
    return {} if self_text_records.empty?

    sids = self_text_records.map(&:goods_nomenclature_sid).uniq
    goods_nomenclature_item_ids = self_text_records.filter_map(&:goods_nomenclature_item_id).uniq

    labels_by_sid = GoodsNomenclatureLabel
      .where(goods_nomenclature_sid: sids)
      .as_hash(:goods_nomenclature_sid)

    atar_keywords_by_item_id =
      if AdminConfiguration.enabled?('search_atars_enabled')
        TariffKnowledge::PublicAtarRuling
          .actual
          .where(goods_nomenclature_item_id: goods_nomenclature_item_ids)
          .select(:goods_nomenclature_item_id, :keywords, :derived_facts)
          .order(:goods_nomenclature_item_id, :ref)
          .all
          .group_by(&:goods_nomenclature_item_id)
          .transform_values { |rulings| rulings.flat_map(&:search_terms).compact_blank.uniq }
      else
        {}
      end

    gns_by_sid = GoodsNomenclature
      .where(goods_nomenclature_sid: sids)
      .eager(:search_references, ancestors: [:search_references])
      .all
      .index_by(&:goods_nomenclature_sid)

    self_text_records.each_with_object({}) do |record, hash|
      sid = record.goods_nomenclature_sid
      gn = gns_by_sid[sid]
      all_refs = (gn&.search_references || []) + (gn&.ancestors&.flat_map(&:search_references) || [])
      builder = new(
        record,
        labels: labels_by_sid[sid],
        search_references: all_refs,
        atar_keywords: atar_keywords_by_item_id[record.goods_nomenclature_item_id],
      )
      hash[sid] = builder.call
    end
  end

private

  attr_reader :self_text_record, :labels, :search_references, :atar_keywords

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

  def atar_keywords_section
    "ATAR keywords: #{normalized_atar_keywords.join(', ')}"
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

    values = labels.send(field)
    return [] if values.nil?

    Array(values).reject(&:blank?)
  end

  def reference_titles
    @reference_titles ||= (search_references || []).filter_map { |r| r.title.presence }.uniq
  end

  def normalized_atar_keywords
    @normalized_atar_keywords ||= Array(atar_keywords).compact_blank.uniq
  end
end

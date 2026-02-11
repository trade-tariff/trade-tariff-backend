class LabelSuggestionsUpdaterService
  LABEL_TYPES = [
    SearchSuggestion::TYPE_KNOWN_BRAND,
    SearchSuggestion::TYPE_COLLOQUIAL_TERM,
    SearchSuggestion::TYPE_SYNONYM,
  ].freeze

  LABEL_FIELDS = {
    'known_brands' => SearchSuggestion::TYPE_KNOWN_BRAND,
    'colloquial_terms' => SearchSuggestion::TYPE_COLLOQUIAL_TERM,
    'synonyms' => SearchSuggestion::TYPE_SYNONYM,
  }.freeze

  def initialize(goods_nomenclature)
    @goods_nomenclature = goods_nomenclature
  end

  def call
    SearchSuggestion.unrestrict_primary_key

    delete_existing_label_suggestions
    insert_new_label_suggestions

    SearchSuggestion.restrict_primary_key
  end

  private

  def delete_existing_label_suggestions
    SearchSuggestion
      .where(goods_nomenclature_sid: @goods_nomenclature.goods_nomenclature_sid)
      .where(type: LABEL_TYPES)
      .delete
  end

  def insert_new_label_suggestions
    label = GoodsNomenclatureLabel
      .where(goods_nomenclature_sid: @goods_nomenclature.goods_nomenclature_sid)
      .first

    return if label.nil?

    suggestions = build_suggestions(label)
    return if suggestions.empty?

    SearchSuggestion.dataset.insert_conflict(
      constraint: :search_suggestions_pkey,
      update: {
        value: Sequel[:excluded][:value],
        goods_nomenclature_sid: Sequel[:excluded][:goods_nomenclature_sid],
        goods_nomenclature_class: Sequel[:excluded][:goods_nomenclature_class],
        priority: Sequel[:excluded][:priority],
        updated_at: Sequel[:excluded][:updated_at],
      },
    ).multi_insert(suggestions.map(&:values))
  end

  def build_suggestions(label)
    now = Time.zone.now

    LABEL_FIELDS.flat_map do |field, type|
      terms = (label.labels&.dig(field) || [])
        .filter_map { |t| t.to_s.downcase.strip.presence }
        .uniq

      terms.map do |term|
        SearchSuggestion.build(
          id: "#{label.goods_nomenclature_sid}_#{type}_#{Digest::MD5.hexdigest(term)}",
          value: term,
          type: type,
          goods_nomenclature_sid: label.goods_nomenclature_sid,
          goods_nomenclature_class: label.goods_nomenclature_type,
          created_at: now,
          updated_at: now,
        )
      end
    end
  end
end

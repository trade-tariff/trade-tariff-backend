class GeneratedLabelFilter
  MAX_SYNONYMS = 8
  MAX_COLLOQUIAL_TERMS = 8

  class << self
    # Filters generated label terms before they reach GoodsNomenclatureLabel.build.
    # Manual admin edits do not pass through here.
    def call(item)
      # Commodity descriptions are often generic. Literal absence is not
      # evidence that a generated brand association is incorrect.
      item.merge(
        'known_brands' => terms(item['known_brands']),
        'synonyms' => capped_terms(item['synonyms'], MAX_SYNONYMS),
        'colloquial_terms' => capped_terms(item['colloquial_terms'], MAX_COLLOQUIAL_TERMS),
      )
    end

  private

    def capped_terms(values, cap)
      terms(values).first(cap)
    end

    def terms(values)
      Array(values).map { |value| value.to_s.strip }.reject(&:empty?).uniq
    end
  end
end

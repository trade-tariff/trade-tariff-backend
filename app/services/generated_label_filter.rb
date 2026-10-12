class GeneratedLabelFilter
  MAX_SYNONYMS = 8
  MAX_COLLOQUIAL_TERMS = 8

  class << self
    # Filters generated label terms before they reach GoodsNomenclatureLabel.build.
    # Manual admin edits do not pass through here.
    def call(item, contextual_description)
      description = contextual_description.to_s

      item.merge(
        'known_brands' => supported_brands(item['known_brands'], description),
        'synonyms' => capped_terms(item['synonyms'], MAX_SYNONYMS),
        'colloquial_terms' => capped_terms(item['colloquial_terms'], MAX_COLLOQUIAL_TERMS),
      )
    end

  private

    def supported_brands(brands, description)
      terms(brands).select { |brand| named_in?(brand, description) }
    end

    def capped_terms(values, cap)
      terms(values).first(cap)
    end

    def terms(values)
      Array(values).map { |value| value.to_s.strip }.reject(&:empty?).uniq
    end

    def named_in?(brand, description)
      return false if description.empty?

      description.match?(/\b#{Regexp.escape(brand)}\b/i)
    end
  end
end

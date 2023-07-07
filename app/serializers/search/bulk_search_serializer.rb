module Search
  class BulkSearchSerializer < ::Serializer
    def serializable_hash(_opts = {})
      {
        number_of_digits: record.number_of_digits,
        short_code: record.short_code,
        indexed_descriptions: record.indexed_descriptions.join('|'),
        indexed_tradeset_descriptions: record.indexed_tradeset_descriptions.join('|'),
        search_references: record.search_references.join('|'),
        intercept_terms: record.intercept_terms.join('|'),
      }
    end
  end
end
